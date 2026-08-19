import Foundation
import XCTest
@testable import TypeTide

final class DiagnosticsPrivacyTests: XCTestCase {
    func testDiagnosticSchemaContainsOperationalMetadataOnly() throws {
        let event = DiagnosticEvent(
            name: .translation,
            outcome: "failure",
            backend: "ollama",
            captureMethod: "accessibility",
            errorCategory: "network",
            firstTokenMilliseconds: 120,
            totalMilliseconds: 450,
            inputCharacterCount: 42
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(event)) as? [String: Any]
        )
        let forbidden = ["text", "translation", "clipboard", "application", "url", "key", "credential"]
        for key in object.keys {
            XCTAssertFalse(forbidden.contains(key.lowercased()), "Sensitive diagnostic field: \(key)")
        }
    }

    func testShortcutActionsCoverPopupAndReplacementModes() {
        XCTAssertTrue(ShortcutAction.smartPopup.usesPopup)
        XCTAssertFalse(ShortcutAction.smartReplace.usesPopup)
        XCTAssertEqual(Set(ShortcutAction.allCases.map(\.rawValue)).count, 6)
    }
}
