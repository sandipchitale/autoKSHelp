import AppKit
import ApplicationServices
import KSCore

enum MenuReader {
    static func isTrusted(prompt: Bool) -> Bool {
        let opts = ["AXTrustedCheckOptionPrompt" as CFString: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    private static func attr<T>(_ el: AXUIElement, _ name: String) -> T? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success else { return nil }
        return v as? T
    }

    /// Reads all shortcut items (with alternates linked) from the app's menu bar. Blocking; call off-main.
    static func read(pid: pid_t) -> [ShortcutItem] {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 1.0)
        guard let bar: AXUIElement = attr(app, "AXMenuBar"),
              let tops: [AXUIElement] = attr(bar, "AXChildren") else { return [] }
        var out: [ShortcutItem] = []
        for (i, top) in tops.enumerated() {
            guard let title: String = attr(top, "AXTitle"), !title.isEmpty else { continue }
            if i == 0 && title == "Apple" { continue }
            out += readMenu(of: top, topTitle: title, path: [title])
        }
        return out
    }

    private static func readMenu(of owner: AXUIElement, topTitle: String, path: [String]) -> [ShortcutItem] {
        guard let kids: [AXUIElement] = attr(owner, "AXChildren"),
              let menu = kids.first,
              let items: [AXUIElement] = attr(menu, "AXChildren") else { return [] }
        var siblings: [ShortcutItem] = []
        var nested: [ShortcutItem] = []
        for it in items {
            guard let title: String = attr(it, "AXTitle"), !title.isEmpty else { continue }
            if let enabled: Bool = attr(it, "AXEnabled"), !enabled { continue }
            let sub = readMenu(of: it, topTitle: topTitle, path: path + [title])
            nested += sub
            let char: String? = attr(it, "AXMenuItemCmdChar")
            let vk: Int? = (attr(it, "AXMenuItemCmdVirtualKey") as NSNumber?)?.intValue
            let key = ShortcutFormat.keyName(char: char, virtualKey: vk)
            if key == nil {
                // No shortcut: skip submenu containers, keep plain commands.
                let children: [AXUIElement]? = attr(it, "AXChildren")
                if !(children ?? []).isEmpty { continue }
            }
            let mods = (attr(it, "AXMenuItemCmdModifiers") as NSNumber?)?.intValue ?? 0
            let item = ShortcutItem(menu: topTitle, path: (path + [title]).joined(separator: " › "),
                                    title: title, key: key ?? "", modifiers: key == nil ? 0 : mods, keyToken: key ?? "")
            item.payload = it
            siblings.append(item)
        }
        return ShortcutFormat.linkAlternates(siblings) + nested
    }
}

extension MenuReader {
    /// Triggers the menu item, equivalent to pressing its shortcut. Blocking; call off-main.
    static func perform(_ item: ShortcutItem) {
        guard let obj = item.payload else { return }
        let el = obj as! AXUIElement
        AXUIElementPerformAction(el, "AXPress" as CFString)
    }
}
