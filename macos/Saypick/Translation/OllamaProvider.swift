//
//  OllamaProvider.swift
//  Saypick
//
//  本地 Ollama 后端。
//

import Foundation
import Ollama

struct OllamaProvider: TranslationProvider {
    let id = "ollama"
    let host: String
    let port: Int
    let model: String

    init(host: String = AppSettings.ollamaHost,
         port: Int = AppSettings.ollamaPort,
         model: String = AppSettings.ollamaModel) {
        self.host = host
        self.port = port
        self.model = model
    }

    func stream(_ request: TranslationRequest) -> AsyncThrowingStream<String, Error> {
        let model = self.model
        let host = self.host
        let port = self.port
        return AsyncThrowingStream { continuation in
            let task = Task {
                guard let url = URL(string: "\(host):\(port)") else {
                    continuation.finish(throwing: TranslationError.notConfigured("Invalid Ollama host"))
                    return
                }
                guard let modelID = Model.ID(rawValue: model) else {
                    continuation.finish(throwing: TranslationError.notConfigured("Invalid Ollama model: \(model)"))
                    return
                }
                let client = Ollama.Client(host: url)
                let prompt = TranslationPrompt.plain(request.text, target: request.target, source: request.source, style: request.style)
                do {
                    let stream = client.generateStream(
                        model: modelID,
                        prompt: prompt,
                        options: [
                            "temperature": .double(OllamaConfig.temperature),
                            "top_p": .double(OllamaConfig.topP),
                            "top_k": .int(OllamaConfig.topK)
                        ]
                    )
                    for try await chunk in stream {
                        if Task.isCancelled { break }
                        continuation.yield(chunk.response)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: TranslationError.network(error.localizedDescription))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
