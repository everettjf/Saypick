//
//  BrandIcon.swift
//  Saypick
//
//  应用统一品牌符号。菜单栏图标若引用了系统里不存在的 SF Symbol，
//  NSStatusItem 会渲染成空白（宽度趋近于零），看起来就像 App 根本没启动。
//  这里在运行时校验符号有效性并逐级回退，保证任何系统上都有可见图标。
//

import AppKit

enum BrandIcon {
    /// 依次尝试的候选符号；排在前面的样式更贴合品牌，后面的兼容性更好。
    private static let candidates = [
        "character.textbox.badge.sparkles", // 若未来系统真的提供该符号则优先使用
        "character.textbox",                // SF Symbols 2+，所有受支持的 macOS 都有
        "textformat",
    ]

    /// 第一个在当前系统上真实存在的符号名。
    static let symbolName: String = {
        for name in candidates where NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil {
            return name
        }
        return "globe"
    }()
}
