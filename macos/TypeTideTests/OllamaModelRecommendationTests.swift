import XCTest
@testable import TypeTide

final class OllamaModelRecommendationTests: XCTestCase {
    func testRecommendationUsesMemoryBudgetAndLargestFittingModel() {
        let models = ["qwen:1.5b", "qwen:3b", "qwen:7b", "qwen:14b", "qwen:32b"]
        XCTAssertEqual(
            OllamaModelResolver.recommendation(from: models, physicalMemoryBytes: 8 * 1_073_741_824)?.model,
            "qwen:7b"
        )
        XCTAssertEqual(
            OllamaModelResolver.recommendation(from: models, physicalMemoryBytes: 24 * 1_073_741_824)?.model,
            "qwen:14b"
        )
        XCTAssertEqual(
            OllamaModelResolver.recommendation(from: models, physicalMemoryBytes: 64 * 1_073_741_824)?.model,
            "qwen:32b"
        )
    }

    func testRecommendationFallsBackToSmallestOrFirstUnspecifiedModel() {
        XCTAssertEqual(
            OllamaModelResolver.recommendation(from: ["huge:70b", "large:32b"], physicalMemoryBytes: 4 * 1_073_741_824)?.model,
            "large:32b"
        )
        XCTAssertEqual(
            OllamaModelResolver.recommendation(from: ["custom:latest"], physicalMemoryBytes: 16 * 1_073_741_824)?.model,
            "custom:latest"
        )
    }
}
