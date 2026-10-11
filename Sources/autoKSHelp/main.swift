import AppKit

// Plain AppKit entry point: a SwiftUI App scene (even an empty Settings one) opens a stray window.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
