#!/bin/zsh
# Build, codesign with stable identity, install to /Applications, and launch.
# Uses a local code-signing certificate (CmdTab Local Signing or autoKSHelp Local Signing)
# so the Accessibility grant survives rebuilds without repeatedly re-prompting.
set -euo pipefail
cd "$(dirname "$0")"

KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
IDENTITY="${CODESIGN_IDENTITY:-}"

if [[ -z "$IDENTITY" ]]; then
    if security find-certificate -c "CmdTab Local Signing" "$KEYCHAIN" >/dev/null 2>&1; then
        IDENTITY="CmdTab Local Signing"
    elif security find-certificate -c "autoKSHelp Local Signing" "$KEYCHAIN" >/dev/null 2>&1; then
        IDENTITY="autoKSHelp Local Signing"
    else
        IDENTITY="autoKSHelp Local Signing"
    fi
fi

if ! security find-certificate -c "$IDENTITY" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "Creating self-signed code-signing certificate '$IDENTITY'..."
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    cat > "$tmp/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $IDENTITY
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF
    openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
        -config "$tmp/cert.cnf" -keyout "$tmp/key.pem" -out "$tmp/cert.pem" 2>/dev/null
    openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" \
        -name "$IDENTITY" -passout pass:autoks -out "$tmp/cert.p12"
    security import "$tmp/cert.p12" -k "$KEYCHAIN" -P autoks -T /usr/bin/codesign
    echo "Trusting the certificate for code signing (macOS will ask for your password)..."
    security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$tmp/cert.pem"
fi

export CODESIGN_IDENTITY="$IDENTITY"
./build.sh
codesign --verify --deep --strict autoKSHelp.app
pkill -x autoKSHelp 2>/dev/null && sleep 0.5 || true
rm -rf /Applications/autoKSHelp.app
cp -R autoKSHelp.app /Applications/
open /Applications/autoKSHelp.app
echo "Installed and launched /Applications/autoKSHelp.app (signed with: $IDENTITY)"
