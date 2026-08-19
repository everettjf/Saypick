import Foundation
import XCTest
@testable import TypeTide

final class SharedContractTests: XCTestCase {
    private struct Contracts: Decodable {
        struct Detection: Decodable { let text: String; let expected: String }
        struct Prompt: Decodable {
            let source: String
            let target: String
            let style: String
            let required: [String]
            let forbidden: [String]
        }
        struct Direction: Decodable {
            let text: String
            let mode: String
            let isWrite: Bool
            let native: String
            let foreign: String
            let source: String?
            let target: String
        }
        struct LineAssembly: Decodable { let fragments: [String]; let expectedLines: [String] }
        struct SSE: Decodable { let line: String; let content: String? }
        let languageDetection: [Detection]
        let directionCases: [Direction]
        let lineAssembly: LineAssembly
        let sseCases: [SSE]
        let promptCases: [Prompt]
    }

    func testSharedLanguageAndPromptContracts() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let root = testFile.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("contracts/translation-contracts.json"))
        let contracts = try JSONDecoder().decode(Contracts.self, from: data)

        for item in contracts.languageDetection {
            XCTAssertEqual(Language.detect(in: item.text)?.rawValue, item.expected, item.text)
        }
        for item in contracts.directionCases {
            let mode = try XCTUnwrap(TranslationDirection(rawValue: item.mode))
            let native = try XCTUnwrap(Language(rawValue: item.native))
            let foreign = try XCTUnwrap(Language(rawValue: item.foreign))
            let target = try XCTUnwrap(Language(rawValue: item.target))
            let expectedSource = item.source.flatMap(Language.init(rawValue:))
            let route = TranslationRouting.resolve(
                text: item.text, mode: mode, isWrite: item.isWrite,
                native: native, foreign: foreign
            )
            XCTAssertEqual(route, TranslationRoute(source: expectedSource, target: target), item.text)
        }
        var assembler = StreamingLineAssembler()
        var lines: [String] = []
        for fragment in contracts.lineAssembly.fragments {
            lines += assembler.feed(Data(fragment.utf8))
        }
        lines += assembler.finish()
        XCTAssertEqual(lines, contracts.lineAssembly.expectedLines)
        for item in contracts.sseCases {
            XCTAssertEqual(OpenAISSEDecoder.content(from: item.line), item.content, item.line)
        }
        for item in contracts.promptCases {
            let source = try XCTUnwrap(Language(rawValue: item.source))
            let target = try XCTUnwrap(Language(rawValue: item.target))
            let style = try XCTUnwrap(RewriteStyle(rawValue: item.style))
            let prompt = TranslationPrompt.system(target: target, source: source, style: style)
            for marker in item.required { XCTAssertTrue(prompt.contains(marker), marker) }
            for marker in item.forbidden { XCTAssertFalse(prompt.contains(marker), marker) }
        }
    }
}
