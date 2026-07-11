//
//  OllamaModelResolver.swift
//  Saypick
//
//  默认模型自动探测：若配置的模型未安装，挑一个已安装的非 embedding 模型。
//

import Foundation
import Ollama

enum OllamaModelResolver {
    /// 列出已安装模型名。
    static func installedModels() async -> [String] {
        guard let url = URL(string: "\(AppSettings.ollamaHost):\(AppSettings.ollamaPort)") else { return [] }
        let client = Ollama.Client(host: url)
        do {
            let response = try await client.listModels()
            return response.models.map { $0.name }
        } catch {
            return []
        }
    }

    /// 看起来像 embedding 模型（不能用于生成翻译）。
    private static func isEmbedding(_ name: String) -> Bool {
        let n = name.lowercased()
        return n.contains("embed") || n.contains("bge") || n.contains("minilm")
    }

    /// 若当前设置的模型未安装，则自动选一个已装的生成模型写回设置。
    /// 仅在 Ollama 后端时执行。返回最终使用的模型名（或 nil 表示无可用模型）。
    @discardableResult
    static func ensureValidDefault() async -> String? {
        guard AppSettings.backend == .ollama else { return AppSettings.ollamaModel }
        let installed = await installedModels()
        guard !installed.isEmpty else { return nil }

        let current = AppSettings.ollamaModel
        if installed.contains(current), !isEmbedding(current) {
            return current
        }
        // 优先非 embedding 模型
        let candidate = installed.first(where: { !isEmbedding($0) }) ?? installed.first
        if let candidate {
            AppSettings.ollamaModel = candidate
        }
        return candidate
    }
}
