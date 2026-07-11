//
//  SystemServiceProvider.swift
//  Saypick
//
//  系统服务（Services 菜单）翻译入口。
//

import AppKit
import Foundation

@MainActor
class SystemServiceProvider: NSObject {
    static let shared = SystemServiceProvider()

    override init() {
        super.init()
        NSApp.servicesProvider = self
    }

    // MARK: - Service Methods

    /// 翻译选中文本到目标语言并写回剪贴板。
    @objc func translateSelection(_ pasteboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        guard let selectedText = pasteboard.string(forType: .string) else { return }
        Task { @MainActor in
            let translation = await translate(selectedText)
            pasteboard.clearContents()
            pasteboard.setString(translation, forType: .string)
        }
    }

    // MARK: - Helper

    private func translate(_ text: String) async -> String {
        do {
            return try await TranslationService.shared.translateFully(
                text: text, from: nil, to: LanguageConfig.targetLanguage)
        } catch {
            return text
        }
    }
}
