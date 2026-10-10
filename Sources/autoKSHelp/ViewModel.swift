import AppKit
import KSCore

enum PopupAppearance: String, CaseIterable {
    case system, light, dark
    var symbol: String { self == .light ? "sun.max" : self == .dark ? "moon" : "circle.lefthalf.filled" }
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

@MainActor
final class ViewModel: ObservableObject {
    @Published var appName = ""
    @Published var appIcon: NSImage?
    @Published var items: [ShortcutItem] = []
    @Published var loading = false
    @Published var needsPermission = false
    @Published var optionDown = false
    @Published var query = ""
    @Published var size = CGSize(width: 1200, height: 800)

    @Published var appearance = PopupAppearance(rawValue: UserDefaults.standard.string(forKey: "appearance") ?? "") ?? .light {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "appearance") }
    }

    @Published var showOtherCommands = UserDefaults.standard.bool(forKey: "showOtherCommands") {
        didSet { UserDefaults.standard.set(showOtherCommands, forKey: "showOtherCommands") }
    }

    var othersShown: Bool { showOtherCommands }

    private var target: NSRunningApplication?
    var onHide: () -> Void = {}

    func load(app: NSRunningApplication?) {
        query = ""
        optionDown = NSEvent.modifierFlags.contains(.option)
        items = []
        guard MenuReader.isTrusted(prompt: true) else { needsPermission = true; return }
        needsPermission = false
        target = app
        guard let app else { return }
        appName = app.localizedName ?? "App"
        appIcon = app.icon
        loading = true
        let pid = app.processIdentifier
        Task.detached {
            let result = MenuReader.read(pid: pid)
            await MainActor.run {
                self.items = result
                self.loading = false
            }
        }
    }

    /// Hides the popup and triggers the item in the target app.
    func activate(_ item: ShortcutItem) {
        let app = target
        onHide()
        app?.activate()
        Task.detached {
            try? await Task.sleep(nanoseconds: 150_000_000)
            MenuReader.perform(item)
        }
    }

    /// Runs the shortcut typed in the popup. Needs ⌘ or ⌃ (or an F-key) so plain typing still searches.
    func handleKey(_ event: NSEvent) -> Bool {
        let f = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard let key = ShortcutFormat.eventKey(chars: event.charactersIgnoringModifiers, keyCode: Int(event.keyCode)) else { return false }
        let isFKey = key.count > 1 && key.hasPrefix("F") && Int(key.dropFirst()) != nil
        guard f.contains(.command) || f.contains(.control) || isFKey else { return false }
        var mask = 0
        if f.contains(.shift) { mask |= ShortcutFormat.shift }
        if f.contains(.option) { mask |= ShortcutFormat.option }
        if f.contains(.control) { mask |= ShortcutFormat.control }
        if !f.contains(.command) { mask |= ShortcutFormat.noCommand }
        guard let item = ShortcutFormat.match(items, modifiers: mask, key: key) else { return false }
        activate(item)
        return true
    }

    typealias Group = (menu: String, items: [ShortcutItem])

    /// Items grouped by top-level menu: those with shortcuts first, then the rest.
    func sections(optionDown: Bool, query: String) -> (withKeys: [Group], others: [Group]) {
        let shown = ShortcutFormat.filter(ShortcutFormat.visible(items, optionDown: optionDown), query: query)
        func group(_ list: [ShortcutItem]) -> [Group] {
            var order: [String] = []
            var dict: [String: [ShortcutItem]] = [:]
            for i in list {
                if dict[i.menu] == nil { order.append(i.menu) }
                dict[i.menu, default: []].append(i)
            }
            return order.map { ($0, dict[$0]!) }
        }
        let others = othersShown ? group(shown.filter { !$0.hasShortcut }) : []
        return (group(shown.filter(\.hasShortcut)), others)
    }

    var sections: (withKeys: [Group], others: [Group]) { sections(optionDown: optionDown, query: query) }

    /// First item in display order (for Enter).
    var firstShown: ShortcutItem? {
        let s = sections
        return s.withKeys.first?.items.first ?? s.others.first?.items.first
    }
}
