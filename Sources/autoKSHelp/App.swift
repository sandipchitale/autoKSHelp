import SwiftUI
import Carbon.HIToolbox

@main
struct AutoKSHelpApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popup: PopupController!
    private var hotKeys: [HotKey] = []
    private var otherCommandsItem: NSMenuItem!

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
        menu.addItem(withTitle: "Show Shortcuts (⌃⌥⌘/)", action: #selector(show), keyEquivalent: "").target = self
        otherCommandsItem = NSMenuItem(title: "Show Other Commands", action: #selector(toggleShowOtherCommands), keyEquivalent: "")
        otherCommandsItem.target = self
        otherCommandsItem.state = popup.model.showOtherCommands ? .on : .off
        menu.addItem(otherCommandsItem)
        menu.addItem(withTitle: "Accessibility Settings…", action: #selector(openSettings), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit autoKSHelp", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        menu.delegate = self

        // ⌃⌥⌘/ cycles shortcuts → +other commands → hidden; ⇧⌃⌥⌘/ opens with other commands, then toggles them.
        let base = UInt32(controlKey | optionKey | cmdKey)
        hotKeys = [
            HotKey(id: 1, keyCode: UInt32(kVK_ANSI_Slash), modifiers: base) { [weak self] in self?.popup.toggle() },
            HotKey(id: 2, keyCode: UInt32(kVK_ANSI_Slash), modifiers: base | UInt32(shiftKey)) { [weak self] in self?.popup.toggleOthers() },
        ]
        _ = MenuReader.isTrusted(prompt: true)
    }

    @objc func show() { popup.show() }

    @objc func toggleShowOtherCommands() {
        popup.model.showOtherCommands.toggle()
        otherCommandsItem?.state = popup.model.showOtherCommands ? .on : .off
    }

    @objc func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        otherCommandsItem?.state = popup.model.showOtherCommands ? .on : .off
    }
}

private extension NSStatusItem {
    static func systemStatusBarItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "command.square", accessibilityDescription: "autoKSHelp")
        return item
    }
}
