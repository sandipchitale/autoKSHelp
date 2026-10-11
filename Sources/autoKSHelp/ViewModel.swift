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
    /// Whether alternates are shown (latched: each Option press toggles it).
    @Published var optionDown = false
    private var optionHeld = false
    private var optionPending = false
    private(set) var shiftDown = false
    private var shiftPending = false
    /// Keyboard/hover selection (nil = first item).
    @Published var selection: UUID?
    /// Set by keyboard navigation only, so the view scrolls to it (hover must not scroll).
    @Published var scrollTarget: UUID?
    @Published var query = ""
    @Published var size = CGSize(width: 1200, height: 800)

    @Published var appearance = PopupAppearance(rawValue: UserDefaults.standard.string(forKey: "appearance") ?? "") ?? .light {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "appearance") }
    }

    @Published var showOtherCommands = UserDefaults.standard.bool(forKey: "showOtherCommands") {
        didSet { UserDefaults.standard.set(showOtherCommands, forKey: "showOtherCommands") }
    }

    var othersShown: Bool { showOtherCommands }

    /// Option / Shift toggle only when tapped *exclusively*: pressed and released alone, with no other
    /// key or modifier in between (so ⇧Tab, ⌥⌘W or Shift+Option together don't toggle anything).
    func modifiersChanged(_ f: NSEvent.ModifierFlags) {
        let opt = f.contains(.option), shift = f.contains(.shift)
        let count = [opt, shift, f.contains(.command), f.contains(.control)].filter { $0 }.count
        if count > 1 { optionPending = false; shiftPending = false }
        if opt && count == 1 && !optionHeld { optionPending = true }
        if shift && count == 1 && !shiftDown { shiftPending = true }
        if !opt && optionHeld && optionPending { optionDown.toggle() }
        if !shift && shiftDown && shiftPending { showOtherCommands.toggle() }
        if !opt { optionPending = false }
        if !shift { shiftPending = false }
        optionHeld = opt
        shiftDown = shift
    }

    /// Any key press cancels a pending Option/Shift tap.
    func keyPressed() { optionPending = false; shiftPending = false }

    private var target: NSRunningApplication?
    var onHide: () -> Void = {}

    func load(app: NSRunningApplication?) {
        query = ""
        optionHeld = NSEvent.modifierFlags.contains(.option)
        optionDown = optionHeld  // Option already held at open: start with alternates shown
        // Shift already held at open (e.g. the ⇧ hotkey): start with other commands shown, no spurious toggle.
        shiftDown = NSEvent.modifierFlags.contains(.shift)
        if shiftDown { showOtherCommands = true }
        items = []
        selection = nil
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

    enum Entry: Identifiable {
        case header(String, Int)
        case row(ShortcutItem)
        case divider(Int)
        var id: String {
            switch self {
            case .header(let m, let n): return "h\(n)-\(m)"
            case .row(let i): return i.id.uuidString
            case .divider(let n): return "d\(n)"
            }
        }
    }

    static let columnCount = 4

    /// Entries flowed into columns (shortcut groups first, then other commands).
    var columns: [[Entry]] {
        let sec = sections
        var entries: [Entry] = []
        for g in sec.withKeys {
            entries.append(.header(g.menu, entries.count))
            entries += g.items.map { .row($0) }
        }
        if !sec.others.isEmpty {
            entries.append(.divider(entries.count))
            for g in sec.others {
                entries.append(.header(g.menu, entries.count))
                entries += g.items.map { .row($0) }
            }
        }
        let cols = Self.columnCount
        let chunk = max(1, Int((Double(entries.count) / Double(cols)).rounded(.up)))
        var result: [[Entry]] = []
        var i = 0
        while i < entries.count || result.count < cols {
            if i >= entries.count { result.append([]); continue }
            var col = Array(entries[i..<min(i + chunk, entries.count)])
            if case .row(let first)? = col.first { col.insert(.header(first.menu + " (cont.)", i), at: 0) }
            result.append(col)
            i += chunk
        }
        return result
    }

    private func rows(_ columns: [[Entry]]) -> [[ShortcutItem]] {
        columns.map { $0.compactMap { if case .row(let i) = $0 { return i } else { return nil } } }
    }

    /// The highlighted item: the selection if still visible, else the first item.
    var effectiveSelection: ShortcutItem? {
        let flat = rows(columns).flatMap { $0 }
        return flat.first { $0.id == selection } ?? flat.first
    }

    /// First item in display order.
    var firstShown: ShortcutItem? { effectiveSelection }

    func activateSelected() { if let item = effectiveSelection { activate(item) } }

    enum Direction { case up, down, left, right, next, previous }

    func move(_ d: Direction) {
        let cols = rows(columns)
        let flat = cols.flatMap { $0 }
        guard !flat.isEmpty, let cur = effectiveSelection else { return }
        func select(_ item: ShortcutItem) { selection = item.id; scrollTarget = item.id }
        if d == .next || d == .previous {
            let i = flat.firstIndex { $0.id == cur.id } ?? 0
            select(flat[(i + (d == .next ? 1 : flat.count - 1)) % flat.count])
            return
        }
        guard let c = cols.firstIndex(where: { $0.contains { $0.id == cur.id } }),
              let r = cols[c].firstIndex(where: { $0.id == cur.id }) else { return }
        switch d {
        case .up: select(cols[c][max(0, r - 1)])
        case .down: select(cols[c][min(cols[c].count - 1, r + 1)])
        case .left, .right:
            let step = d == .left ? -1 : 1
            var n = c + step
            while cols.indices.contains(n), cols[n].isEmpty { n += step }
            if cols.indices.contains(n) { select(cols[n][min(r, cols[n].count - 1)]) }
        default: break
        }
    }
}
