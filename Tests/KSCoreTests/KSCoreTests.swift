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
