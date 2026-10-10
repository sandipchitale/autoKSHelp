import Foundation

/// A menu item with a keyboard shortcut. `alternate` is the Option-held variant, if any.
public final class ShortcutItem: Identifiable {
    public let id = UUID()
    public let menu: String
    public let path: String
    public let title: String
    public let key: String
    public let modifiers: Int
    public let keyToken: String
    public var hasShortcut: Bool { !key.isEmpty }
    public var alternate: ShortcutItem?
    public var isAlternate = false
    /// Opaque handle to the live menu item (an AXUIElement in the app).
    public var payload: AnyObject?

    public init(menu: String, path: String, title: String, key: String, modifiers: Int, keyToken: String) {
        self.menu = menu; self.path = path; self.title = title
        self.key = key; self.modifiers = modifiers; self.keyToken = keyToken
    }
}

public enum ShortcutFormat {
    // AX modifier mask: bit0 shift, bit1 option, bit2 control, bit3 = NO command.
    public static let shift = 1, option = 2, control = 4, noCommand = 8

    public static func modifierGlyphs(_ mask: Int) -> String {
        var s = ""
        if mask & control != 0 { s += "⌃" }
        if mask & option != 0 { s += "⌥" }
        if mask & shift != 0 { s += "⇧" }
        if mask & noCommand == 0 { s += "⌘" }
        return s
    }

    static let virtualKeys: [Int: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 71: "⌧", 76: "⌤",
        115: "↖", 116: "⇞", 117: "⌦", 119: "↘", 121: "⇟",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
        106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20",
    ]

    /// Returns the display string for the key part, or nil if there is none.
    public static func keyName(char: String?, virtualKey: Int?) -> String? {
        if let c = char, !c.isEmpty, c != " " || virtualKey == nil {
            return c == " " ? "Space" : c.uppercased()
        }
        if let vk = virtualKey, let name = virtualKeys[vk] { return name }
        return nil
    }

    /// Key name for a typed key event; special keys resolve by key code, others by character.
    public static func eventKey(chars: String?, keyCode: Int) -> String? {
        if let name = virtualKeys[keyCode] { return name }
        guard let c = chars, !c.isEmpty else { return nil }
        return c.uppercased()
    }

    /// Finds the item (base or alternate) whose shortcut is exactly `modifiers` + `key`.
    public static func match(_ items: [ShortcutItem], modifiers: Int, key: String) -> ShortcutItem? {
        items.first { $0.modifiers == modifiers && $0.key == key }
    }

    public static func display(modifiers: Int, key: String) -> String {
        key.isEmpty ? "" : modifierGlyphs(modifiers) + key
    }

    /// Pairs Option alternates with their base item among one menu's siblings.
    public static func linkAlternates(_ items: [ShortcutItem]) -> [ShortcutItem] {
        var result: [ShortcutItem] = []
        for item in items {
            if item.hasShortcut, item.modifiers & option != 0,
               let base = result.last(where: {
                   !$0.isAlternate && $0.keyToken == item.keyToken && $0.modifiers == item.modifiers & ~option
               }) {
                item.isAlternate = true
                base.alternate = item
            }
            result.append(item)
        }
        return result
    }

    /// Items to display: base items, or with Option held, alternates replacing their bases.
    public static func visible(_ items: [ShortcutItem], optionDown: Bool) -> [ShortcutItem] {
        items.filter { !$0.isAlternate }.map { optionDown ? ($0.alternate ?? $0) : $0 }
    }

    public static func filter(_ items: [ShortcutItem], query: String) -> [ShortcutItem] {
        let terms = query.lowercased().split(separator: " ").map(String.init)
        guard !terms.isEmpty else { return items }
        return items.filter { item in
            let hay = (item.path + " " + display(modifiers: item.modifiers, key: item.key)).lowercased()
            return terms.allSatisfy { hay.contains($0) }
        }
    }
}
