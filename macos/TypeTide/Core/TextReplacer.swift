//
//  TextReplacer.swift
//  TypeTide
//
//  原地替换：合成粘贴，保留撤销栈；用后还原剪贴板。
//

import AppKit

enum TextReplacer {
#if DEBUG
    /// XCTest seam for exercising the complete popup replacement flow without
    /// requiring a CI runner to hold a macOS Accessibility grant.
    @MainActor static var replacementOverride: ((String, Bool) async -> Void)?
#endif

    /// 用译文替换。selectAll=true 时先 ⌘A 全选（整框改写），否则直接粘到当前选区。
    @MainActor
    static func replace(with text: String, selectAll: Bool) async {
#if DEBUG
        if let replacementOverride {
            await replacementOverride(text, selectAll)
            return
        }
#endif
        let pb = NSPasteboard.general
        let saved = PasteboardHelper.snapshot()

        pb.clearContents()
        pb.setString(text, forType: .string)

        if selectAll {
            Keyboard.press(Keyboard.aKey, command: true)
            try? await Task.sleep(nanoseconds: 40_000_000)
        }
        Keyboard.press(Keyboard.vKey, command: true)

        // 等粘贴完成再还原剪贴板，避免还原把待粘贴内容覆盖掉
        try? await Task.sleep(nanoseconds: 150_000_000)
        PasteboardHelper.restore(saved)
    }
}
