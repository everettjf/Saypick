import AppKit
import XCTest
@testable import TypeTide

final class PasteboardRestorationTests: XCTestCase {
    func testSnapshotRestoresAllItemsAndRepresentations() throws {
        let pasteboard = NSPasteboard(name: .init("TypeTideTests.\(UUID().uuidString)"))
        pasteboard.clearContents()

        let first = NSPasteboardItem()
        first.setString("original text", forType: .string)
        first.setData(Data([0x01, 0x02, 0x03]), forType: .init("com.typetide.test.binary"))
        let second = NSPasteboardItem()
        second.setString("second item", forType: .string)
        XCTAssertTrue(pasteboard.writeObjects([first, second]))

        let snapshot = PasteboardHelper.snapshot(from: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString("temporary translation", forType: .string)
        PasteboardHelper.restore(snapshot, to: pasteboard)

        let restored = try XCTUnwrap(pasteboard.pasteboardItems)
        XCTAssertEqual(restored.count, 2)
        XCTAssertEqual(restored[0].string(forType: .string), "original text")
        XCTAssertEqual(restored[0].data(forType: .init("com.typetide.test.binary")), Data([0x01, 0x02, 0x03]))
        XCTAssertEqual(restored[1].string(forType: .string), "second item")
        pasteboard.releaseGlobally()
    }

    func testEmptySnapshotRestoresEmptyPasteboard() {
        let pasteboard = NSPasteboard(name: .init("TypeTideTests.\(UUID().uuidString)"))
        pasteboard.setString("temporary", forType: .string)
        PasteboardHelper.restore([], to: pasteboard)
        XCTAssertEqual(pasteboard.pasteboardItems?.count ?? 0, 0)
        pasteboard.releaseGlobally()
    }
}
