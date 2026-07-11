//
//  AppSettings.swift
//  Saypick
//
//  统一配置入口（替代散落的 UserDefaults 读写）。
//

import Foundation

/// 翻译后端
enum TranslationBackend: String, CaseIterable, Identifiable {
    case ollama
    case openai

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .ollama: return "Local (Ollama)"
        case .openai: return "OpenAI-compatible"
        }
    }
}

/// 划词触发方式
enum SelectionTrigger: String, CaseIterable, Identifiable {
    case none      // 仅快捷键
    case icon      // 划词后显示小图标，点击翻译
    case auto      // 划词后直接弹出翻译

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .none: return "Off (shortcut only)"
        case .icon: return "Show floating icon"
        case .auto: return "Auto-translate"
        }
    }
}

/// 改写/翻译风格（仅改写使用；读翻译固定 faithful）
enum RewriteStyle: String, CaseIterable, Identifiable {
    case faithful  // 纯翻译
    case formal    // 正式
    case casual    // 口语
    case polished  // 润色

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .faithful: return "Faithful (plain translation)"
        case .formal: return "Formal"
        case .casual: return "Casual / spoken"
        case .polished: return "Polished"
        }
    }
    /// 注入到 prompt 的风格指令；faithful 返回 nil
    var instruction: String? {
        switch self {
        case .faithful: return nil
        case .formal: return "Use a professional, formal tone."
        case .casual: return "Use a natural, casual, conversational tone."
        case .polished: return "Improve clarity and flow so it reads polished and native, while keeping the original meaning."
        }
    }
}

/// 全局设置。非 View 代码用静态访问；View 用 @AppStorage 直接绑定同名 key。
enum AppSettings {
    enum Keys {
        static let enabled = "isSaypickEnabled"
        static let backend = "translationBackend"

        // OpenAI 兼容
        static let openAIBaseURL = "openAIBaseURL"
        static let openAIKey = "openAIKey"
        static let openAIModel = "openAIModel"

        // Ollama
        static let ollamaModel = "selectedModel"   // 沿用旧 key，兼容 ModelsSettingsView

        // 语言：sourceLanguage = 用户母语，targetLanguage = 外语（见 LanguageConfig）
        // 触发快捷键
        static let readShortcut = "readShortcut"
        static let rewriteShortcut = "rewriteShortcut"

        // 翻译方向（读 / 写 各自独立；默认 auto 双向）
        static let readDirection = "readDirection"
        static let rewriteDirection = "rewriteDirection"

        // 行为
        static let selectionTrigger = "selectionTrigger"
        static let rewritePreview = "rewritePreview"
        static let rewriteStyle = "rewriteStyle"
        static let readStyle = "readStyle"
    }

    private static let d = UserDefaults.standard

    static var isEnabled: Bool {
        get { d.object(forKey: Keys.enabled) as? Bool ?? true }
        set { d.set(newValue, forKey: Keys.enabled) }
    }

    static var backend: TranslationBackend {
        get { TranslationBackend(rawValue: d.string(forKey: Keys.backend) ?? "") ?? .ollama }
        set { d.set(newValue.rawValue, forKey: Keys.backend) }
    }

    // MARK: OpenAI 兼容
    static var openAIBaseURL: String {
        get { d.string(forKey: Keys.openAIBaseURL) ?? "https://api.openai.com/v1" }
        set { d.set(newValue, forKey: Keys.openAIBaseURL) }
    }
    static var openAIKey: String {
        get { d.string(forKey: Keys.openAIKey) ?? "" }
        set { d.set(newValue, forKey: Keys.openAIKey) }
    }
    static var openAIModel: String {
        get { d.string(forKey: Keys.openAIModel) ?? "gpt-4o-mini" }
        set { d.set(newValue, forKey: Keys.openAIModel) }
    }

    // MARK: Ollama
    static var ollamaModel: String {
        get { d.string(forKey: Keys.ollamaModel) ?? "qwen2.5:3b" }
        set { d.set(newValue, forKey: Keys.ollamaModel) }
    }
    static var ollamaHost: String { OllamaConfig.host }
    static var ollamaPort: Int { OllamaConfig.port }

    // MARK: 快捷键
    static var readShortcut: KeyboardShortcutPreference {
        get { shortcut(forKey: Keys.readShortcut) ?? .init(keyCode: 2, modifiers: [.option]) }   // ⌥D
        set { saveShortcut(newValue, forKey: Keys.readShortcut) }
    }
    static var rewriteShortcut: KeyboardShortcutPreference {
        get { shortcut(forKey: Keys.rewriteShortcut) ?? .init(keyCode: 15, modifiers: [.option]) } // ⌥R
        set { saveShortcut(newValue, forKey: Keys.rewriteShortcut) }
    }

    // MARK: 翻译方向
    static var readDirection: TranslationDirection {
        get { TranslationDirection(rawValue: d.string(forKey: Keys.readDirection) ?? "") ?? .auto }
        set { d.set(newValue.rawValue, forKey: Keys.readDirection) }
    }
    static var rewriteDirection: TranslationDirection {
        get { TranslationDirection(rawValue: d.string(forKey: Keys.rewriteDirection) ?? "") ?? .auto }
        set { d.set(newValue.rawValue, forKey: Keys.rewriteDirection) }
    }

    // MARK: 行为
    static var selectionTrigger: SelectionTrigger {
        get { SelectionTrigger(rawValue: d.string(forKey: Keys.selectionTrigger) ?? "") ?? .none }
        set { d.set(newValue.rawValue, forKey: Keys.selectionTrigger) }
    }
    static var rewritePreview: Bool {
        get { d.bool(forKey: Keys.rewritePreview) }   // 默认 false = 直接替换
        set { d.set(newValue, forKey: Keys.rewritePreview) }
    }
    static var rewriteStyle: RewriteStyle {
        get { RewriteStyle(rawValue: d.string(forKey: Keys.rewriteStyle) ?? "") ?? .faithful }
        set { d.set(newValue.rawValue, forKey: Keys.rewriteStyle) }
    }
    static var readStyle: RewriteStyle {
        get { RewriteStyle(rawValue: d.string(forKey: Keys.readStyle) ?? "") ?? .faithful }
        set { d.set(newValue.rawValue, forKey: Keys.readStyle) }
    }

    private static func shortcut(forKey key: String) -> KeyboardShortcutPreference? {
        guard let data = d.data(forKey: key),
              let s = try? JSONDecoder().decode(KeyboardShortcutPreference.self, from: data) else { return nil }
        return s
    }
    private static func saveShortcut(_ s: KeyboardShortcutPreference, forKey key: String) {
        if let data = try? JSONEncoder().encode(s) { d.set(data, forKey: key) }
    }
}
