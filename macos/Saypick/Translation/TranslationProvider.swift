//
//  TranslationProvider.swift
//  Saypick
//
//  翻译后端抽象：所有 provider 输出流式增量文本。
//

import Foundation

enum TranslationError: LocalizedError {
    case notConfigured(String)
    case network(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .notConfigured(let m): return m
        case .network(let m): return m
        case .empty: return "Empty translation"
        }
    }
}

/// 一次翻译请求
struct TranslationRequest {
    let text: String
    /// 源语言；nil 表示让模型自动判断
    let source: Language?
    let target: Language
    /// 风格（仅改写用；读翻译为 faithful）
    var style: RewriteStyle = .faithful
}

protocol TranslationProvider {
    var id: String { get }
    /// 返回译文增量（流式）。调用方负责拼接。
    func stream(_ request: TranslationRequest) -> AsyncThrowingStream<String, Error>
}

/// 统一的提示词构造。支持风格（faithful 为纯翻译）。
enum TranslationPrompt {
    static func system(target: Language, source: Language?, style: RewriteStyle = .faithful) -> String {
        let from = source?.displayName ?? "the detected language"
        let styleLine = style.instruction.map { " " + $0 } ?? ""
        return """
        You are a professional translation engine. Translate the user's text from \(from) into \(target.displayName).\(styleLine) \
        Output ONLY the translation, with no quotes, no explanations, no extra notes. Preserve the original meaning and formatting.
        """
    }

    /// 用于不支持 system role 的纯 generate 接口
    static func plain(_ text: String, target: Language, source: Language?, style: RewriteStyle = .faithful) -> String {
        let from = source?.displayName ?? "the source language"
        let styleLine = style.instruction.map { " " + $0 } ?? ""
        return """
        Translate the following text from \(from) to \(target.displayName).\(styleLine) Only output the translation, no explanation.

        \(text)
        """
    }
}
