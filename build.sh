#!/bin/zsh
set -e
cd "$(dirname "$0")"

if [[ -z "${CODESIGN_IDENTITY:-}" ]]; then
    if security find-certificate -c "CmdTab Local Signing" >/dev/null 2>&1; then
        CODESIGN_IDENTITY="CmdTab Local Signing"
    elif security find-certificate -c "autoKSHelp Local Signing" >/dev/null 2>&1; then
        CODESIGN_IDENTITY="autoKSHelp Local Signing"
    else
        CODESIGN_IDENTITY="-"
    fi
fi

swift build -c release
APP=autoKSHelp.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/autoKSHelp" "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
codesign --force --sign "$CODESIGN_IDENTITY" "$APP"
echo "Built $APP (signed with: $CODESIGN_IDENTITY) — run: open $APP"
