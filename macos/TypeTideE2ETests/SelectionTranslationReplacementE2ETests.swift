import AppKit
import XCTest
@testable import TypeTide

private struct MockStreamingProvider: TranslationProvider {
    let id = "e2e-mock"

    func stream(_ request: TranslationRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            XCTAssertEqual(request.text, "你好世界")
            XCTAssertEqual(request.target, .english)
            continuation.yield("MOCK_")
            continuation.yield("TRANSLATION_OK")
            continuation.finish()
        }
    }
}

@MainActor
final class SelectionTranslationReplacementE2ETests: XCTestCase {
    override func tearDown() async throws {
        PopupController.shared.close()
        TranslationService.shared.providerOverride = nil
        TextReplacer.replacementOverride = nil
        try await super.tearDown()
    }

    func testSelectedTextStreamsIntoPopupAndReplaceUpdatesEditor() async throws {
        let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 480, height: 180))
        editor.string = "前缀 你好世界 后缀"
        let selected = (editor.string as NSString).range(of: "你好世界")
        editor.setSelectedRange(selected)
        XCTAssertEqual((editor.string as NSString).substring(with: editor.selectedRange()), "你好世界")

        TranslationService.shared.providerOverride = MockStreamingProvider()
        TextReplacer.replacementOverride = { [weak editor] replacement, selectAll in
            guard let editor else { return }
            if selectAll { editor.selectAll(nil) }
            editor.insertText(replacement, replacementRange: editor.selectedRange())
        }

        // This is the same entry point used after SelectionCapture has obtained
        // a real AX selection. It creates the production NSPanel and streams into it.
        TriggerController.shared.presentRead(
            text: (editor.string as NSString).substring(with: editor.selectedRange()),
            element: nil,
            range: nil
        )

        XCTAssertTrue(PopupController.shared.isVisible)
        let model = try XCTUnwrap(PopupController.shared.currentModel)
        try await waitUntil { model.translation == "MOCK_TRANSLATION_OK" }
        XCTAssertEqual(model.translation, "MOCK_TRANSLATION_OK")
        try await waitUntil { model.tidePhase == .complete }

        model.onReplace?()
        try await waitUntil { editor.string.contains("MOCK_TRANSLATION_OK") }

        XCTAssertEqual(editor.string, "前缀 MOCK_TRANSLATION_OK 后缀")
        XCTAssertFalse(PopupController.shared.isVisible)
    }

    private func waitUntil(timeout: Duration = .seconds(3), condition: @escaping @MainActor () -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            guard clock.now < deadline else {
                XCTFail("Timed out waiting for end-to-end state")
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}
