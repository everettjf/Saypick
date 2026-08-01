import XCTest
@testable import TypeTide

final class TranslationPromptTests: XCTestCase {
    func testSystemPromptContainsDirectionAndNoExtraOutputRule() {
        let prompt = TranslationPrompt.system(target: .english, source: .chinese)

        XCTAssertTrue(prompt.contains("from 中文 (Chinese) into English"))
        XCTAssertTrue(prompt.contains("Output ONLY the translation"))
        XCTAssertFalse(prompt.contains("professional, formal tone"))
    }

    func testRewriteStylesAreInjected() {
        let formal = TranslationPrompt.system(target: .french, source: .english, style: .formal)
        let polished = TranslationPrompt.plain("hello", target: .spanish, source: .english, style: .polished)

        XCTAssertTrue(formal.contains("professional, formal tone"))
        XCTAssertTrue(polished.contains("Improve clarity and flow"))
        XCTAssertTrue(polished.hasSuffix("hello"))
    }
}
