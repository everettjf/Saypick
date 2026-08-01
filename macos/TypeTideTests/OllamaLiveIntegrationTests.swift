import Foundation
import XCTest
@testable import TypeTide

final class OllamaLiveIntegrationTests: XCTestCase {
    private struct TagsResponse: Decodable {
        struct Model: Decodable {
            let name: String
            let details: Details?
        }

        struct Details: Decodable {
            let families: [String]?
        }

        let models: [Model]
    }

    private func discoverGenerationModel() async throws -> String {
        let endpoint = URL(string: "http://127.0.0.1:11434/api/tags")!
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(from: endpoint)
        } catch {
            throw XCTSkip("Ollama is not reachable on localhost:11434: \(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw XCTSkip("Ollama /api/tags did not return HTTP 200")
        }

        let tags = try JSONDecoder().decode(TagsResponse.self, from: data)
        guard let model = tags.models.first(where: { model in
            let name = model.name.lowercased()
            let families = model.details?.families?.map { $0.lowercased() } ?? []
            return !name.contains("embed") && !families.contains("bert")
        }) else {
            throw XCTSkip("Ollama is running but has no installed text-generation model")
        }
        return model.name
    }

    func testLiveOllamaStreamsARealEnglishTranslation() async throws {
        let model = try await discoverGenerationModel()

        let provider = OllamaProvider(host: "http://127.0.0.1", port: 11434, model: model)
        let request = TranslationRequest(
            text: "你好世界，今天天气很好。",
            source: .chinese,
            target: .english,
            style: .faithful
        )

        var chunks: [String] = []
        for try await delta in provider.stream(request) {
            chunks.append(delta)
        }

        let translation = chunks.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertGreaterThan(chunks.count, 0, "Ollama should produce at least one streaming chunk")
        XCTAssertFalse(translation.isEmpty)
        XCTAssertNotEqual(translation, request.text)
        XCTAssertTrue(translation.range(of: "[A-Za-z]", options: .regularExpression) != nil,
                      "Expected an English-looking translation, got: \(translation)")
        print("LIVE_OLLAMA_TRANSLATION=\(translation)")
        print("LIVE_OLLAMA_CHUNKS=\(chunks.count)")
        print("LIVE_OLLAMA_MODEL=\(model)")
    }
}
