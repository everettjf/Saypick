import XCTest
@testable import TypeTide

final class OpenAIProviderTests: XCTestCase {
    func testMissingAPIKeyFailsBeforeNetworkRequest() async {
        let provider = OpenAIProvider(baseURL: "https://example.com/v1", apiKey: "", model: "test")

        do {
            for try await _ in provider.stream(.init(text: "hello", source: .english, target: .chinese)) {}
            XCTFail("Expected missing-key error")
        } catch let error as TranslationError {
            XCTAssertEqual(error.errorDescription, "Missing OpenAI API key")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInsecureRemoteHTTPIsRejected() async {
        let provider = OpenAIProvider(baseURL: "http://example.com/v1", apiKey: "secret", model: "test")

        do {
            for try await _ in provider.stream(.init(text: "hello", source: .english, target: .chinese)) {}
            XCTFail("Expected insecure-transport error")
        } catch let error as TranslationError {
            XCTAssertTrue(error.errorDescription?.contains("insecure HTTP") == true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
