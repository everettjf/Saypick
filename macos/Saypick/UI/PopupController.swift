//
//  PopupController.swift
//  Saypick
//
//  管理单个翻译弹窗 NSPanel：定位、显示、外部点击关闭。
//

import AppKit
import SwiftUI

@MainActor
final class PopupController {
    static let shared = PopupController()
    private init() {}

    private var panel: NSPanel?
    private var clickMonitor: Any?
    private var keyMonitor: Any?

    private let width: CGFloat = 380
    private let estimatedHeight: CGFloat = 150

    /// 在锚点附近显示弹窗，返回可写入流式结果的 model。
    @discardableResult
    func show(original: String, target: Language, anchor: NSRect, onReplace: (() -> Void)?) -> TranslationPopupModel {
        close()

        let model = TranslationPopupModel(original: original, target: target)
        model.onReplace = onReplace
        model.onCopy = { [weak model] in
            guard let model else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(model.translation, forType: .string)
        }

        let frame = computeFrame(anchor: anchor)
        let panel = NSPanel(contentRect: frame,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: TranslationPopupView(model: model))
        panel.orderFrontRegardless()

        self.panel = panel
        installDismissMonitors()
        return model
    }

    func close() {
        removeMonitors()
        panel?.orderOut(nil)
        panel = nil
    }

    var isVisible: Bool { panel != nil }

    private func computeFrame(anchor: NSRect) -> NSRect {
        let screen = NSScreen.screens.first { $0.frame.contains(NSPoint(x: anchor.midX, y: anchor.midY)) }
            ?? NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        var x = anchor.origin.x
        // 默认在文字下方
        var y = anchor.origin.y - estimatedHeight - 8
        // 下方放不下 → 放上方
        if y < visible.minY + 8 {
            y = anchor.origin.y + anchor.height + 8
        }
        x = max(visible.minX + 8, min(x, visible.maxX - width - 8))
        y = max(visible.minY + 8, min(y, visible.maxY - estimatedHeight - 8))
        return NSRect(x: x, y: y, width: width, height: estimatedHeight)
    }

    private func installDismissMonitors() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.keyCode == 53 { // Escape
                Task { @MainActor in self?.close() }
                return nil
            }
            return event
        }
    }

    private func removeMonitors() {
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        clickMonitor = nil
        keyMonitor = nil
    }
}
