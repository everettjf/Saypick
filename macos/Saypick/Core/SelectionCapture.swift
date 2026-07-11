//
//  SelectionCapture.swift
//  Saypick
//
//  取词：优先 AX kAXSelectedText，兜底模拟 ⌘C 复制并还原剪贴板。
//

import ApplicationServices
import AppKit

/// 改写模式抓取的上下文
struct RewriteCapture {
    let text: String
    /// true = 取的是整个输入框（替换时需先全选）；false = 取的是当前选区
    let isWholeField: Bool
    let element: AXUIElement?
    let selectedRange: CFRange?
}

enum SelectionCapture {

    // MARK: 读模式：拿到选中的文字

    /// 读模式取词：AX 选区优先，兜底复制。返回 (文字, 元素, 选区range) 供定位。
    @MainActor
    static func readSelection() async -> (text: String, element: AXUIElement?, range: CFRange?)? {
        let element = focusedElement()
        if let element {
            if let t = axSelectedText(element), !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return (t, element, axSelectedRange(element))
            }
        }
        if let copied = await copyViaPasteboard(),
           !copied.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (copied, element, element.flatMap { axSelectedRange($0) })
        }
        return nil
    }

    // MARK: 写模式：拿到选区或整个输入框

    @MainActor
    static func captureForRewrite() async -> RewriteCapture? {
        if let element = focusedElement() {
            // 有选区 → 只改选区
            if let range = axSelectedRange(element), range.length > 0,
               let sel = axSelectedText(element),
               !sel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return RewriteCapture(text: sel, isWholeField: false, element: element, selectedRange: range)
            }
            // 无选区 → 改整个输入框
            if let value = axValue(element),
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return RewriteCapture(text: value, isWholeField: true, element: element, selectedRange: nil)
            }
        }
        // AX 拿不到 → 兜底复制（按选区处理）
        if let copied = await copyViaPasteboard(),
           !copied.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return RewriteCapture(text: copied, isWholeField: false, element: nil, selectedRange: nil)
        }
        return nil
    }

    // MARK: - AX helpers

    static func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        let err = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused)
        guard err == .success, let element = focused else { return nil }
        return (element as! AXUIElement)
    }

    static func axSelectedText(_ element: AXUIElement) -> String? {
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value)
        guard err == .success else { return nil }
        return value as? String
    }

    static func axValue(_ element: AXUIElement) -> String? {
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        guard err == .success else { return nil }
        return value as? String
    }

    static func axSelectedRange(_ element: AXUIElement) -> CFRange? {
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value)
        guard err == .success, let value else { return nil }
        var range = CFRange()
        if AXValueGetValue(value as! AXValue, .cfRange, &range) {
            return range
        }
        return nil
    }

    // MARK: - 模拟复制兜底

    @MainActor
    static func copyViaPasteboard() async -> String? {
        let pb = NSPasteboard.general
        let saved = PasteboardHelper.snapshot()
        let beforeCount = pb.changeCount

        Keyboard.press(Keyboard.cKey, command: true)

        var result: String?
        // 最多等 ~400ms 让目标 app 写入剪贴板
        for _ in 0..<20 {
            try? await Task.sleep(nanoseconds: 20_000_000)
            if pb.changeCount != beforeCount {
                result = pb.string(forType: .string)
                break
            }
        }
        PasteboardHelper.restore(saved)
        return result
    }
}
