import SwiftUI
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popup: PopupController!
    private var hotKeys: [HotKey] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        popup = PopupController()

        statusItem = NSStatusItem.systemStatusBarItem()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        statusItem.button?.toolTip = "autoKSHelp v\(version)"
        let menu = NSMenu()
        let titleItem = NSMenuItem(title: "autoKSHelp v\(version)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Show Shortcuts (⌃⌘/)", action: #selector(show), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Accessibility Settings…", action: #selector(openSettings), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit autoKSHelp", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        // ⌃⌘/ shows (shortcuts only) or hides; ⇧⌃⌘/ opens with other commands shown. Once open, Shift alone toggles them.
        let base = UInt32(controlKey | cmdKey)
        hotKeys = [
            HotKey(id: 1, keyCode: UInt32(kVK_ANSI_Slash), modifiers: base) { [weak self] in self?.popup.toggle() },
            HotKey(id: 2, keyCode: UInt32(kVK_ANSI_Slash), modifiers: base | UInt32(shiftKey)) { [weak self] in self?.popup.openWithOthers() },
        ]
        _ = MenuReader.isTrusted(prompt: true)
    }

    @objc func show() { popup.show() }

    @objc func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

private extension NSStatusItem {
    static func systemStatusBarItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "command.square", accessibilityDescription: "autoKSHelp")
        return item
    }
}
