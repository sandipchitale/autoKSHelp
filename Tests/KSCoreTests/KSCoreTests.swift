import XCTest
@testable import KSCore

final class KSCoreTests: XCTestCase {
    func item(_ title: String, _ key: String, _ mods: Int) -> ShortcutItem {
        ShortcutItem(menu: "File", path: "File › \(title)", title: title, key: key, modifiers: mods, keyToken: key)
    }

    func testGlyphs() {
        XCTAssertEqual(ShortcutFormat.modifierGlyphs(0), "⌘")
        XCTAssertEqual(ShortcutFormat.modifierGlyphs(1 | 2), "⌥⇧⌘")
        XCTAssertEqual(ShortcutFormat.modifierGlyphs(4 | 8), "⌃")
    }

    func testAlternates() {
        let items = ShortcutFormat.linkAlternates([item("Close", "W", 0), item("Close All", "W", 2), item("Open", "O", 0)])
        XCTAssertEqual(ShortcutFormat.visible(items, optionDown: false).map(\.title), ["Close", "Open"])
        XCTAssertEqual(ShortcutFormat.visible(items, optionDown: true).map(\.title), ["Close All", "Open"])
    }

    func testFilterAndKeys() {
        let items = [item("Close", "W", 0), item("Open", "O", 0)]
        XCTAssertEqual(ShortcutFormat.filter(items, query: "clo").count, 1)
        XCTAssertEqual(ShortcutFormat.filter(items, query: "⌘o").count, 1)
        XCTAssertEqual(ShortcutFormat.keyName(char: "", virtualKey: 36), "↩")
        XCTAssertEqual(ShortcutFormat.keyName(char: "a", virtualKey: nil), "A")
    }

    func testTypedShortcutMatch() {
        let items = ShortcutFormat.linkAlternates([item("Close", "W", 0), item("Close All", "W", 2)])
        XCTAssertEqual(ShortcutFormat.match(items, modifiers: 2, key: "W")?.title, "Close All")
        XCTAssertEqual(ShortcutFormat.match(items, modifiers: 0, key: "W")?.title, "Close")
        XCTAssertNil(ShortcutFormat.match(items, modifiers: 1, key: "W"))
        XCTAssertEqual(ShortcutFormat.eventKey(chars: "w", keyCode: 13), "W")
        XCTAssertEqual(ShortcutFormat.eventKey(chars: "\u{F702}", keyCode: 123), "←")
    }

    func testNoShortcutItems() {
        let plain = item("Reload", "", 0)
        XCTAssertFalse(plain.hasShortcut)
        XCTAssertEqual(ShortcutFormat.display(modifiers: 0, key: ""), "")
        XCTAssertEqual(ShortcutFormat.filter([plain, item("Open", "O", 0)], query: "⌘").count, 1)
        XCTAssertEqual(ShortcutFormat.filter([plain], query: "reload").count, 1)
    }
}

import PDFKit

final class ExportTests: XCTestCase {
    func rows(_ n: Int, group: String = "File") -> [ExportEntry] {
        [.header(group)] + (0..<n).map { .row(title: "Item \($0)", keys: ["⌘", "\($0 % 10)"], hint: nil) }
    }

    func testPaginationContinuesHeadersAndFillsColumns() {
        let pages = ExportLayout.paginate(rows(20), columns: 2, rowsPerColumn: 8)
        XCTAssertEqual(pages.count, 2)                       // 4 columns -> 2 pages of 2
        XCTAssertEqual(pages[0][1].first, .header("File (cont.)"))
        XCTAssertTrue(pages.flatMap { $0 }.allSatisfy { $0.count <= 8 })
        let rowTotal = pages.flatMap { $0 }.flatMap { $0 }.filter { if case .row = $0 { return true } else { return false } }.count
        XCTAssertEqual(rowTotal, 20)
    }

    func testAlternateStaysWithItsRow() {
        var entries: [ExportEntry] = [.header("File")]
        for i in 0..<10 { entries += [.row(title: "R\(i)", keys: ["⌘", "\(i)"], hint: nil), .alt(title: "A\(i)", keys: ["⌥", "⌘", "\(i)"])] }
        let cols = ExportLayout.paginate(entries, columns: 4, rowsPerColumn: 7).flatMap { $0 }
        for c in cols {
            if case .alt? = c.first { XCTFail("alternate separated from its row") }
            if case .row? = c.last, c.count >= 1 { /* a row at the bottom must not have lost its alt */
                XCTFail("row at column bottom without its alternate") }
        }
        let html = ExportHTML.render(ExportSnapshot(appName: "X", entries: entries, filter: "", alternates: true, others: false, dark: false))
        XCTAssertTrue(html.contains("class=\"row alt\"") && html.contains("+ 10 alternates") && html.contains("<span class=\"altlbl\">Alternates (⌥)</span>") && html.contains("<kbd class=\"opt\">⌥</kbd>"))
    }

    func testLogoEmbeddedInHTML() {
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!
        let s = ExportSnapshot(appName: "X", entries: [], filter: "", alternates: false, others: false, dark: false, iconPNG: png)
        XCTAssertTrue(ExportHTML.render(s).contains("<img class=\"logo\" alt=\"\" src=\"data:image/png;base64,iVBOR"))
        let none = ExportSnapshot(appName: "X", entries: [], filter: "", alternates: false, others: false, dark: false)
        XCTAssertFalse(ExportHTML.render(none).contains("<img"))
    }

    func testNoOrphanHeader() {
        let entries = rows(5, group: "A") + rows(5, group: "B")
        let cols = ExportLayout.paginate(entries, columns: 4, rowsPerColumn: 7).flatMap { $0 }
        for c in cols { if case .header? = c.last { XCTFail("orphan header at column bottom") } }
    }

    func testHTMLEscapesAndLandscape() {
        let s = ExportSnapshot(appName: "A<B>", entries: [.row(title: "x & y", keys: ["⌘", "K"], hint: nil)],
                               filter: "q\"", alternates: true, others: false, dark: false)
        let html = ExportHTML.render(s)
        XCTAssertTrue(html.contains("size: landscape"))
        XCTAssertTrue(html.contains("A&lt;B&gt;") && html.contains("x &amp; y") && html.contains("filter “q&quot;”"))
        XCTAssertTrue(html.contains("<kbd>⌘</kbd><kbd>K</kbd>"))
    }

    @MainActor func testPDFIsLandscapeAndMultiPage() throws {
        var entries: [ExportEntry] = []
        for g in 0..<6 { entries += rows(40, group: "Menu \(g)") }
        let s = ExportSnapshot(appName: "Demo", entries: entries, filter: "", alternates: false, others: false, dark: false)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ks-test-\(UUID()).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try PDFExporter.write(s, to: url)
        let doc = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertGreaterThan(doc.pageCount, 1)
        let box = try XCTUnwrap(doc.page(at: 0)).bounds(for: .mediaBox)
        XCTAssertGreaterThan(box.width, box.height)
        XCTAssertTrue((doc.string ?? "").contains("Item 7"))
        if let dir = ProcessInfo.processInfo.environment["KS_EXPORT_SAMPLE_DIR"] {
            var alt: [ExportEntry] = [.header("Claude")]
            for i in 0..<12 { alt += [.row(title: "Hide Others \(i)", keys: ["⌘", "H"], hint: nil), .alt(title: "Hide Antigravity \(i)", keys: ["⌥", "⌘", "H"])] }
            let icon = NSImage(named: NSImage.applicationIconName).flatMap { img -> Data? in
                guard let t = img.tiffRepresentation, let r = NSBitmapImageRep(data: t) else { return nil }
                return r.representation(using: .png, properties: [:])
            }
            let dark = ExportSnapshot(appName: "Claude", entries: alt, filter: "", alternates: true, others: false, dark: true, iconPNG: icon)
            try ExportHTML.render(dark).write(toFile: dir + "/alt-dark.html", atomically: true, encoding: .utf8)
            try PDFExporter.write(dark, to: URL(fileURLWithPath: dir).appendingPathComponent("alt-dark.pdf"))
            try PDFExporter.write(s, to: URL(fileURLWithPath: dir).appendingPathComponent("sample.pdf"))
            try ExportHTML.render(s).write(toFile: dir + "/sample.html", atomically: true, encoding: .utf8)
        }
    }
}
