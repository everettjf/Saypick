//
//  TriggerController.swift
//  Saypick
//
//  编排主链路：
//  - 读·划词翻译：快捷键 / 划词图标 / 自动 → 弹窗流式显示译文。
//  - 写·输入改写：快捷键 → 译为目标语言 → 直接替换或先预览。
//

import AppKit
import ApplicationServices

@MainActor
final class TriggerController {
    static let shared = TriggerController()
    private init() {}

    private let readHotkeyID: UInt32 = 1
    private let rewriteHotkeyID: UInt32 = 2

    private var streamTask: Task<Void, Never>?
    private var rewriteTask: Task<Void, Never>?

    /// 母语（读模式的目标 / 写模式的源）
    private var nativeLanguage: Language { LanguageConfig.sourceLanguage }
    /// 外语（写模式的目标）
    private var foreignLanguage: Language { LanguageConfig.targetLanguage }

    // MARK: - 生命周期

    func start() {
        applyEnabledState()
    }

    /// 根据开关 + 快捷键 + 划词设置重新装配触发。
    func applyEnabledState() {
        GlobalShortcutCenter.shared.unregisterAll()
        SelectionMonitor.shared.stop()
        SelectionIconWindow.shared.hide()

        guard AppSettings.isEnabled else { return }

        GlobalShortcutCenter.shared.register(id: readHotkeyID, shortcut: AppSettings.readShortcut) { [weak self] in
            Task { @MainActor in self?.handleRead() }
        }
        GlobalShortcutCenter.shared.register(id: rewriteHotkeyID, shortcut: AppSettings.rewriteShortcut) { [weak self] in
            Task { @MainActor in self?.handleRewrite() }
        }

        setupSelectionTrigger()
    }

    private func setupSelectionTrigger() {
        let mode = AppSettings.selectionTrigger
        guard mode != .none else { return }

        SelectionMonitor.shared.onSelection = { [weak self] text, location, element, range in
            guard let self, AppSettings.isEnabled, AccessibilityPermission.isGranted else { return }
            switch mode {
            case .none:
                break
            case .icon:
                // 图标贴合选区：优先用选区屏幕矩形，拿不到再退回鼠标点
                let anchor = PopupPositioner.anchorRect(element: element, range: range)
                SelectionIconWindow.shared.show(near: anchor, fallback: location) {
                    self.presentRead(text: text, element: element, range: range)
                }
            case .auto:
                self.presentRead(text: text, element: element, range: range)
            }
        }
        SelectionMonitor.shared.start()
    }

    // MARK: - 读·划词翻译

    func handleRead() {
        guard AppSettings.isEnabled, AccessibilityPermission.isGranted else { return }
        Task { @MainActor in
            guard let cap = await SelectionCapture.readSelection() else { return }
            presentRead(text: cap.text, element: cap.element, range: cap.range)
        }
    }

    /// 显示读翻译弹窗并流式填充（供快捷键 / 图标 / 自动模式共用）。
    func presentRead(text: String, element: AXUIElement?, range: CFRange?) {
        let anchor = PopupPositioner.anchorRect(element: element, range: range)
        let dir = resolveDirection(text: text, mode: AppSettings.readDirection, isWrite: false)
        let model = PopupController.shared.show(original: text, target: dir.to, anchor: anchor, onReplace: nil)
        model.onReplace = { [weak model] in
            guard let model, !model.translation.isEmpty else { return }
            Task { @MainActor in
                PopupController.shared.close()
                await TextReplacer.replace(with: model.translation, selectAll: false)
            }
        }
        model.onRetarget = { [weak self, weak model] newTarget in
            guard let self, let model else { return }
            model.targetLanguage = newTarget
            self.runTranslationStream(text: text, from: dir.from, to: newTarget,
                                      style: AppSettings.readStyle, into: model)
        }
        runTranslationStream(text: text, from: dir.from, to: dir.to,
                             style: AppSettings.readStyle, into: model)
    }

    // MARK: - 方向决策与共用流式

    /// 按模式决定 from/to。
    /// - auto：检测选中文字语言；母语→外语、外语→母语、第三种/检测不确定→（读:母语 / 写:外语）。
    /// - 固定模式：跳过检测，直接用配置好的方向（对中英混排等检测易错场景更稳）。
    private func resolveDirection(text: String, mode: TranslationDirection, isWrite: Bool) -> (from: Language?, to: Language) {
        let native = nativeLanguage
        let foreign = foreignLanguage
        switch mode {
        case .nativeToForeign:
            return (native, foreign)
        case .foreignToNative:
            return (foreign, native)
        case .auto:
            let detected = Language.detect(in: text)
            let to: Language
            if detected == native {
                to = foreign
            } else if detected == foreign {
                to = native
            } else {
                to = isWrite ? foreign : native
            }
            return (detected, to)
        }
    }

    /// 共用的流式翻译，把结果写入弹窗 model（读 / 改写预览 / 弹窗重定向复用）。
    private func runTranslationStream(text: String, from: Language?, to: Language,
                                      style: RewriteStyle, into model: TranslationPopupModel) {
        streamTask?.cancel()
        model.translation = ""
        model.isLoading = true
        model.errorText = nil
        streamTask = Task { @MainActor in
            do {
                for try await delta in TranslationService.shared.stream(text: text, from: from, to: to, style: style) {
                    if Task.isCancelled { return }
                    model.translation += delta
                    model.isLoading = false
                }
                model.isLoading = false
                if model.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    model.errorText = "No translation returned"
                }
            } catch {
                model.isLoading = false
                model.errorText = (error as? TranslationError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    // MARK: - 写·输入改写

    func handleRewrite() {
        guard AppSettings.isEnabled, AccessibilityPermission.isGranted else { return }
        rewriteTask?.cancel()
        rewriteTask = Task { @MainActor in
            guard let cap = await SelectionCapture.captureForRewrite() else { return }
            let style = AppSettings.rewriteStyle
            let dir = resolveDirection(text: cap.text, mode: AppSettings.rewriteDirection, isWrite: true)

            if AppSettings.rewritePreview {
                // 先预览：弹窗显示译文 + Replace 按钮（顶部可改目标语言）
                let anchor = PopupPositioner.anchorRect(element: cap.element, range: cap.selectedRange)
                let model = PopupController.shared.show(original: cap.text, target: dir.to, anchor: anchor, onReplace: nil)
                model.onReplace = { [weak model] in
                    guard let model, !model.translation.isEmpty else { return }
                    Task { @MainActor in
                        PopupController.shared.close()
                        await TextReplacer.replace(with: model.translation, selectAll: cap.isWholeField)
                    }
                }
                model.onRetarget = { [weak self, weak model] newTarget in
                    guard let self, let model else { return }
                    model.targetLanguage = newTarget
                    self.runTranslationStream(text: cap.text, from: dir.from, to: newTarget, style: style, into: model)
                }
                runTranslationStream(text: cap.text, from: dir.from, to: dir.to, style: style, into: model)
            } else {
                // 直接替换
                do {
                    let translated = try await TranslationService.shared.translateFully(
                        text: cap.text, from: dir.from, to: dir.to, style: style)
                    await TextReplacer.replace(with: translated, selectAll: cap.isWholeField)
                } catch {
                    let anchor = PopupPositioner.anchorRect(element: cap.element, range: cap.selectedRange)
                    let model = PopupController.shared.show(original: cap.text, target: dir.to, anchor: anchor, onReplace: nil)
                    model.isLoading = false
                    model.errorText = (error as? TranslationError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }
}
