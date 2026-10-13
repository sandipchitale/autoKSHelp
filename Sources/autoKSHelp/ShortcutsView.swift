import SwiftUI
import KSCore
import AppKit

/// Forces the enclosing scroll view to use a legacy (always-visible) vertical scroller, so its
/// width is always reserved and the layout never shifts when scrolling becomes necessary.
struct ReservedScroller: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let sv = view.enclosingScrollView else { return }
            sv.scrollerStyle = .legacy
            sv.hasVerticalScroller = true
            sv.autohidesScrollers = false
            sv.hasHorizontalScroller = false
        }
    }
}

struct ShortcutsView: View {
    @ObservedObject var model: ViewModel
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: model.size.width, height: model.size.height)
        .background(Color(nsColor: NSColor(name: nil) { a in
            a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 0.13, alpha: 1) : .white
        }))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary))
        .onExitCommand { model.onHide() }
        .onAppear { focused = true }
        .onChange(of: model.items.count) { _ in focused = true }
    }

    private static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"

    private var header: some View {
        HStack(spacing: 10) {
            if let icon = model.appIcon {
                Image(nsImage: icon).resizable().frame(width: 24, height: 24)
            }
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search \(model.appName) shortcuts, or type one", text: $model.query)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($focused)
                .onSubmit { model.activateSelected() }
            // Constant labels (the key is part of the text), so the header never shifts.
            Toggle(isOn: $model.optionDown) { Text("⌥ Alternates") }
                .toggleStyle(.button)
                .help(model.optionDown ? "Showing alternate actions (press ⌥ Option or click to hide)"
                                       : "Press ⌥ Option or click to show alternate actions (e.g. Close All instead of Close)")
            Toggle(isOn: $model.showOtherCommands) { Text("⇧ Other Commands") }
                .toggleStyle(.button)
                .help(model.othersShown ? "Showing commands without shortcuts (press ⇧ Shift or click to hide)"
                                        : "Press ⇧ Shift or click to show commands without shortcuts")
            Toggle(isOn: $model.viewInsteadOfSave) { Image(systemName: "eye") }
                .toggleStyle(.button)
                .help(model.viewInsteadOfSave
                      ? "View on: the PDF / HTML buttons open the file for viewing (saved in a temporary folder, no save dialog)"
                      : "View off: the PDF / HTML buttons ask where to save. Turn on to just view the file.")
            Button { model.onExport(.pdf) } label: { Image(systemName: "doc.richtext") }
                .disabled(model.items.isEmpty)
                .help("Save the current view as a landscape PDF")
            Button { model.onExport(.html) } label: { Image(systemName: "chevron.left.forwardslash.chevron.right") }
                .disabled(model.items.isEmpty)
                .help("Save the current view as a landscape HTML file")
            Picker("Appearance", selection: $model.appearance) {
                ForEach(PopupAppearance.allCases, id: \.self) { a in
                    Image(systemName: a.symbol).help(a.rawValue.capitalized).tag(a)
                }
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            Text("v\(Self.version)").font(.caption).foregroundStyle(.secondary).fixedSize()
        }
        .padding(14)
    }

    @ViewBuilder private var content: some View {
        if model.needsPermission {
            message("Accessibility permission required",
                    "Enable autoKSHelp in System Settings › Privacy & Security › Accessibility, then try again.")
        } else if model.loading {
            VStack { Spacer(); ProgressView(); Spacer() }.frame(maxWidth: .infinity)
        } else if model.sections.withKeys.isEmpty && model.sections.others.isEmpty {
            let emptyTitle = model.othersShown ? "No commands found" : "No shortcuts found"
            let emptyDetail = model.query.isEmpty
                ? (model.othersShown ? "This app exposes no menu commands." : "This app exposes no keyboard shortcuts.")
                : "Nothing matches “\(model.query)”."
            message(emptyTitle, emptyDetail)
        } else {
            columnsView
        }
    }

    private let rowH: CGFloat = 24


    private var columnsView: some View {
        let columns = model.columns
        let selected = model.effectiveSelection?.id
        return ScrollViewReader { proxy in ScrollView(.vertical) { HStack(alignment: .top, spacing: 0) {
            ForEach(Array(columns.enumerated()), id: \.offset) { idx, col in
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(col) { e in
                        switch e {
                        case .header(let m, _):
                            Text(m.uppercased())
                                .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                                .frame(height: rowH, alignment: .bottomLeading)
                                .padding(.horizontal, 12)
                        case .row(let item):
                            row(item, selected: item.id == selected)
                        case .divider:
                            Text("OTHER COMMANDS (NO SHORTCUT)")
                                .font(.caption.weight(.heavy)).foregroundStyle(Color.accentColor)
                                .frame(height: rowH, alignment: .bottomLeading)
                                .padding(.horizontal, 12)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                if idx < columns.count - 1 { Divider() }
            }
        }
        .padding(.vertical, 4)
        .background(ReservedScroller())
        }
        .onChange(of: model.scrollTarget) { id in if let id { proxy.scrollTo(id) } }
        }
    }

    private func row(_ item: ShortcutItem, selected: Bool) -> some View {
        HStack(spacing: 6) {
            Text(item.title).font(.system(size: 13)).lineLimit(1).truncationMode(.tail)
                .foregroundStyle(item.isAlternate ? Color.accentColor : Color.primary)
                .padding(.leading, item.isAlternate ? 14 : 0)
            Spacer(minLength: 6)
            if item.hasShortcut {
                keycaps(item)
            } else {
                Text(item.path.components(separatedBy: " › ").dropLast().joined(separator: " › "))
                    .font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
        }
        .frame(height: rowH)
        .padding(.horizontal, 12)
        .background(selected ? Color.accentColor.opacity(0.22) : .clear)
        .contentShape(Rectangle())
        .id(item.id)
        .onHover { if $0 { model.selection = item.id } }
        .onTapGesture { model.activate(item) }
    }

    private func keycaps(_ item: ShortcutItem) -> some View {
        let glyphs = ShortcutFormat.modifierGlyphs(item.modifiers).map(String.init) + [item.key]
        return HStack(spacing: 3) {
            ForEach(Array(glyphs.enumerated()), id: \.offset) { _, g in
                Text(g)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .frame(minWidth: 18).padding(.horizontal, 2).padding(.vertical, 1)
                    .foregroundStyle(item.isAlternate ? Color.accentColor : Color.primary)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
            }
        }
    }

    private func message(_ title: String, _ detail: String) -> some View {
        VStack(spacing: 6) {
            Spacer()
            Text(title).font(.headline)
            Text(detail).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
        }
        .padding(30).frame(maxWidth: .infinity)
    }
}
