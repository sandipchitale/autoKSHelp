import AppKit
import SwiftUI
import Combine

final class PopupPanel: NSPanel {
    var onCancel: () -> Void = {}

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onCancel() }
    private var dragOffset: NSPoint?

    /// Drags the panel from any spot that isn't an interactive control (SwiftUI's hosting view eats background drags).
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            var v = contentView?.hitTest(contentView?.superview?.convert(event.locationInWindow, from: nil) ?? event.locationInWindow)
            var interactive = false
            while let cur = v {
                if cur is NSControl || cur is NSText { interactive = true; break }
                v = cur.superview
            }
            let m = NSEvent.mouseLocation
            dragOffset = interactive ? nil : NSPoint(x: m.x - frame.origin.x, y: m.y - frame.origin.y)
        case .leftMouseDragged:
            if let off = dragOffset {
                let m = NSEvent.mouseLocation
                setFrameOrigin(NSPoint(x: m.x - off.x, y: m.y - off.y))
                return
            }
        case .leftMouseUp:
            dragOffset = nil
        default: break
        }
        super.sendEvent(event)
    }

    override func resignKey() { super.resignKey(); onCancel() }
}

@MainActor
final class PopupController {
    let model = ViewModel()
    private let panel: PopupPanel
    private var monitors: [Any] = []
    private var cancellable: AnyCancellable?
    private var sizeSink: AnyCancellable?

    init() {
        panel = PopupPanel(contentRect: NSRect(x: 0, y: 0, width: 640, height: 520),
                           styleMask: [.borderless, .nonactivatingPanel],
                           backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let host = NSHostingView(rootView: ShortcutsView(model: model))
        host.frame = NSRect(x: 0, y: 0, width: 640, height: 520)
        panel.contentView = host
        panel.appearance = model.appearance.nsAppearance
        cancellable = model.$appearance.sink { [weak self] a in self?.panel.appearance = a.nsAppearance }
        sizeSink = model.$size.dropFirst().receive(on: RunLoop.main).sink { [weak self] size in
            guard let self, self.panel.isVisible else { return }
            self.place(size: size, in: (NSScreen.main ?? NSScreen.screens[0]).visibleFrame)
        }
        panel.onCancel = { [weak self] in self?.hide() }
        model.onHide = { [weak self] in self?.hide() }
    }

    var isVisible: Bool { panel.isVisible }

    /// ⇧-hotkey: open with other commands shown. If already open, Shift itself has just toggled them.
    func openWithOthers() {
        guard !isVisible else { return }
        model.showOtherCommands = true
        show()
    }

    /// Hotkey: show (shortcuts only) or hide.
    func toggle() {
        if isVisible {
            hide()
        } else {
            model.showOtherCommands = false
            show()
        }
    }

    func show() {
        // Capture the frontmost app before the panel appears.
        let front = NSWorkspace.shared.frontmostApplication
        let target = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : front
        model.load(app: target)
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let f = screen.visibleFrame
        let size = CGSize(width: min((f.width * 0.95).rounded(), 4 * 400), height: (f.height * 0.7).rounded())
        model.size = size
        place(size: model.size, in: f)
        panel.makeKeyAndOrderFront(nil)
        installMonitors()
    }

    private func place(size: CGSize, in f: NSRect) {
        panel.setContentSize(size)
        panel.contentView?.frame = NSRect(origin: .zero, size: size)
        panel.setFrameOrigin(NSPoint(x: f.midX - size.width / 2, y: f.midY - size.height / 2))
    }

    func hide() {
        guard panel.isVisible else { return }
        removeMonitors()
        panel.orderOut(nil)
    }

    private func installMonitors() {
        removeMonitors()
        let update: (NSEvent) -> Void = { [weak self] e in
            let flags = e.modifierFlags.intersection(.deviceIndependentFlagsMask)
            Task { @MainActor in self?.model.modifiersChanged(flags) }
        }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { e in update(e); return e }) {
            monitors.append(m)
        }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] e in
            MainActor.assumeIsolated {
                guard let self else { return e }
                self.model.keyPressed()
                if self.handleNavigation(e) { return nil }
                return self.model.handleKey(e) ? nil : e
            }
        }) {
            monitors.append(m)
        }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: update) {
            monitors.append(m)
        }
    }

    /// Arrow keys and Tab / ⇧Tab move the selection. Left/Right only navigate while the search box is empty
    /// (otherwise they move the text cursor).
    private func handleNavigation(_ e: NSEvent) -> Bool {
        let f = e.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard f.isDisjoint(with: [.command, .control, .option]) else { return false }
        switch Int(e.keyCode) {
        case 125: model.move(.down)
        case 126: model.move(.up)
        case 123 where model.query.isEmpty: model.move(.left)
        case 124 where model.query.isEmpty: model.move(.right)
        case 48: model.move(f.contains(.shift) ? .previous : .next)
        default: return false
        }
        return true
    }

    private func removeMonitors() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
    }
}
