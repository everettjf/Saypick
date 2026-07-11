//
//  TranslationService.swift
//  Saypick
//
//  根据设置选择 provider，做缓存与流式输出。
//

import Foundation

@MainActor
final class TranslationService {
    static let shared = TranslationService()
    private init() {}

    private func currentProvider() -> TranslationProvider {
        switch AppSettings.backend {
        case .ollama: return OllamaProvider()
        case .openai: return OpenAIProvider()
        }
    }

    /// 流式翻译。命中缓存时一次性 yield 全文；否则边流边累积，结束后写缓存。
    func stream(text: String, from: Language?, to: Language, style: RewriteStyle = .faithful) -> AsyncThrowingStream<String, Error> {
        let provider = currentProvider()
        let cacheKey = TranslationCache.shared.key(backend: provider.id, from: from, to: to, text: "\(style.rawValue)|\(text)")

        return AsyncThrowingStream { continuation in
            if let cached = TranslationCache.shared.value(for: cacheKey) {
                continuation.yield(cached)
                continuation.finish()
                return
            }
            let task = Task {
                var full = ""
                do {
                    for try await delta in provider.stream(.init(text: text, source: from, target: to, style: style)) {
                        full += delta
                        continuation.yield(delta)
                    }
                    let cleaned = full.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty {
                        TranslationCache.shared.set(cleaned, for: cacheKey)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// 一次性翻译（用于改写：需要完整结果再替换）。
    func translateFully(text: String, from: Language?, to: Language, style: RewriteStyle = .faithful) async throws -> String {
        var full = ""
        for try await delta in stream(text: text, from: from, to: to, style: style) {
            full += delta
        }
        let cleaned = full.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw TranslationError.empty }
        return cleaned
    }
}
