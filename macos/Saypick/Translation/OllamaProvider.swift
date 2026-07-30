//
//  OllamaProvider.swift
//  Saypick
//
//  本地 Ollama 后端。
//

import Foundation

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
                guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continuation.finish(throwing: TranslationError.notConfigured("Missing Ollama model"))
                    return
                }
                guard let url = URL(string: "\(host):\(port)/api/generate") else {
                    continuation.finish(throwing: TranslationError.notConfigured("Invalid Ollama host"))
                    return
                }
                let prompt = TranslationPrompt.plain(request.text, target: request.target, source: request.source, style: request.style)
                do {
                    do {
                        try await performOllamaRequest(
                            url: url, model: model, prompt: prompt, disableThinking: true,
                            continuation: continuation)
                    } catch let error as OllamaHTTPError where error.statusCode == 400 && !Task.isCancelled {
                        // 老版本 Ollama 不认识 think 字段；与 Windows 一致，去掉后兼容重试。
                        try await performOllamaRequest(
                            url: url, model: model, prompt: prompt, disableThinking: false,
                            continuation: continuation)
                    }
                    continuation.finish()
                } catch {
                    let message: String
                    if let httpError = error as? OllamaHTTPError {
                        message = providerMessage(from: httpError.body)
                            ?? "Ollama returned HTTP \(httpError.statusCode)"
                    } else {
                        message = error.localizedDescription
                    }
                    continuation.finish(throwing: TranslationError.network(message))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

private struct OllamaHTTPError: Error {
    let statusCode: Int
    let body: String
}

private func performOllamaRequest(
    url: URL,
    model: String,
    prompt: String,
    disableThinking: Bool,
    continuation: AsyncThrowingStream<String, Error>.Continuation
) async throws {
    var body: [String: Any] = [
        "model": model,
        "prompt": prompt,
        "stream": true,
        "keep_alive": "10m",
        "options": [
            "temperature": OllamaConfig.temperature,
            "top_p": OllamaConfig.topP,
            "top_k": OllamaConfig.topK
        ]
    ]
    if disableThinking { body["think"] = false }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (bytes, response) = try await URLSession.shared.bytes(for: request)
    guard let http = response as? HTTPURLResponse else {
        throw TranslationError.network("Invalid response from Ollama")
    }
    guard (200...299).contains(http.statusCode) else {
        var responseBody = ""
        for try await line in bytes.lines {
            responseBody += line
            if responseBody.count >= 16_384 { break }
        }
        throw OllamaHTTPError(statusCode: http.statusCode, body: responseBody)
    }

    for try await line in bytes.lines {
        if Task.isCancelled { return }
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
        if let error = json["error"] as? String { throw TranslationError.network(error) }
        if let delta = json["response"] as? String, !delta.isEmpty {
            continuation.yield(delta)
        }
    }
}

private func providerMessage(from body: String) -> String? {
    guard let data = body.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(500))
    }
    return json["error"] as? String ?? json["message"] as? String
}
