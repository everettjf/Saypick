//
//  SelectionCapture.h — 取词（对应 macOS 的 SelectionCapture）。
//  优先 UI Automation TextPattern 选区，兜底模拟 Ctrl+C 复制并还原剪贴板。
//
#pragma once
#include <windows.h>
#include <optional>
#include <string>

namespace capture {

struct Capture {
    std::wstring text;
    /// true = 取的是整个输入框（替换时需先全选）；false = 当前选区
    bool isWholeField = false;
    /// 选区屏幕矩形（物理像素）；hasAnchor=false 时无效
    RECT anchor{};
    bool hasAnchor = false;
};

/// 读模式取词：UIA 选区优先，兜底复制。
std::optional<Capture> ReadSelection();

/// 写模式取词：有选区取选区；无选区取整个输入框；UIA 拿不到兜底复制。
std::optional<Capture> CaptureForRewrite();

/// 仅通过 UIA 读当前选区（不动剪贴板；划词监听用）。
std::optional<Capture> UIASelectionOnly();

/// 兜底锚点：光标位置一小块矩形
RECT CursorAnchor();

} // namespace capture
