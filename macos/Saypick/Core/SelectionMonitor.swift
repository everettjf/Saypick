//
//  SelectionMonitor.swift
//  Saypick
//
//  全局监听鼠标抬起，检测其他 app 里的文字选区（仅 AX，不动剪贴板）。
//

import AppKit
import ApplicationServices

@MainActor
final class SelectionMonitor {
    static let shared = SelectionMonitor()
    private init() {}

    private var mouseMonitor: Any?
    private var lastText: String = ""

    /// 选区回调：选中文字、鼠标位置(Cocoa)、AX 元素、选区 range。
    var onSelection: ((_ text: String, _ mouseLocation: NSPoint, _ element: AXUIElement?, _ range: CFRange?) -> Void)?

    func start() {
        stop()
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            Task { @MainActor in self?.handleMouseUp() }
        }
    }

    func stop() {
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        mouseMonitor = nil
        lastText = ""
    }

    private func handleMouseUp() {
        let location = NSEvent.mouseLocation
        Task { @MainActor in
            // 等选区稳定
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard let element = SelectionCapture.focusedElement(),
                  let text = SelectionCapture.axSelectedText(element) else {
                lastText = ""
                return
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { lastText = ""; return }
            // 同一选区不重复触发
            guard trimmed != lastText else { return }
            lastText = trimmed
            onSelection?(text, location, element, SelectionCapture.axSelectedRange(element))
        }
    }
}
