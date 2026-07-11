//
//  OllamaConfig.swift
//  Saypick
//
//  Configuration for Ollama integration
//

import Foundation

struct OllamaConfig {
    /// Ollama 服务器主机地址
    static let host = "http://127.0.0.1"

    /// Ollama 服务器端口
    static let port = 11434

    /// 默认使用的模型名称
    /// 推荐模型：
    /// - qwen2.5:3b - 轻量级，适合快速翻译
    /// - llama3.2:3b - 平衡性能和准确度
    /// - gemma2:2b - 超轻量级选项
    static var defaultModel: String {
        UserDefaults.standard.string(forKey: "selectedModel") ?? "qwen2.5:3b"
    }

    /// 温度参数（0.0-1.0），越低越确定
    static let temperature = 0.3

    /// Top-p 采样参数
    static let topP = 0.9

    /// Top-k 采样参数
    static let topK = 40

    /// 是否启用流式响应
    static let streamingEnabled = true

    /// 请求超时时间（秒）
    static let timeout: TimeInterval = 30.0
}
