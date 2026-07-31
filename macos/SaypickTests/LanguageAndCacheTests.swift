import XCTest
@testable import Saypick

final class LanguageAndCacheTests: XCTestCase {
    func testLanguageDetectionAndUnknownInput() {
        XCTAssertEqual(Language.detect(in: "今天天气很好，我们出去散步吧。"), .chinese)
        XCTAssertEqual(Language.detect(in: "The quick brown fox jumps over the lazy dog."), .english)
        XCTAssertNil(Language.detect(in: "   \n"))
    }

    func testDirectionLabels() {
        XCTAssertEqual(TranslationDirection.nativeToForeign.label(native: .chinese, foreign: .english), "中文 → English")
        XCTAssertEqual(TranslationDirection.foreignToNative.label(native: .chinese, foreign: .english), "English → 中文")
    }

    func testCacheKeyIncludesBackendDirectionAndText() {
        let cache = TranslationCache(capacity: 2)
        let a = cache.key(backend: "openai", from: .chinese, to: .english, text: "你好")
        let b = cache.key(backend: "ollama", from: .chinese, to: .english, text: "你好")

        XCTAssertNotEqual(a, b)
        cache.set("hello", for: a)
        XCTAssertEqual(cache.value(for: a), "hello")
    }

    func testCacheEvictsLeastRecentlyUsedEntry() {
        let cache = TranslationCache(capacity: 2)
        cache.set("A", for: "a")
        cache.set("B", for: "b")
        XCTAssertEqual(cache.value(for: "a"), "A") // a is now most recent
        cache.set("C", for: "c")

        XCTAssertNil(cache.value(for: "b"))
        XCTAssertEqual(cache.value(for: "a"), "A")
        XCTAssertEqual(cache.value(for: "c"), "C")
    }
}
