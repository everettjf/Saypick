//
//  OpenAIProvider.swift
//  Saypick
//
//  OpenAI 兼容后端（chat/completions，SSE 流式）。
//  base URL 可指向官方或任意兼容端点。
//

import Foundation

struct OpenAIProvider: TranslationProvider {
    let id = "openai"
    let baseURL: String
    let apiKey: String
    let model: String

    init(baseURL: String = AppSettings.openAIBaseURL,
         apiKey: String = AppSettings.openAIKey,
         model: String = AppSettings.openAIModel) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
    }

    func stream(_ request: TranslationRequest) -> AsyncThrowingStream<String, Error> {
        let baseURL = self.baseURL
        let apiKey = self.apiKey
        let model = self.model
        return AsyncThrowingStream { continuation in
            let task = Task {
                guard !apiKey.isEmpty else {
                    continuation.finish(throwing: TranslationError.notConfigured("Missing OpenAI API key"))
                    return
                }
                guard let url = URL(string: baseURL.trimmingTrailingSlash + "/chat/completions") else {
                    continuation.finish(throwing: TranslationError.notConfigured("Invalid base URL"))
                    return
                }

                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

                let body: [String: Any] = [
                    "model": model,
                    "stream": true,
                    "temperature": 0.3,
                    "messages": [
                        ["role": "system", "content": TranslationPrompt.system(target: request.target, source: request.source, style: request.style)],
                        ["role": "user", "content": request.text]
                    ]
                ]
                req.httpBody = try? JSONSerialization.data(withJSONObject: body)

                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                        continuation.finish(throwing: TranslationError.network("HTTP \(http.statusCode)"))
                        return
                    }
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let content = delta["content"] as? String else { continue }
                        continuation.yield(content)
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

private extension String {
    var trimmingTrailingSlash: String {
        var s = self
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }
}
