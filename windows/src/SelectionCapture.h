//
//  SelectionCapture.h — 取词（对应 macOS 的 SelectionCapture）。
//  优先 UI Automation TextPattern 选区，兜底模拟 Ctrl+C 复制并还原剪贴板。
//
//  线程约定：UIA* 系列在主线程调用（快，无睡眠）；
//  ClipboardFallbackCopy 内部最长等 ~400ms，必须在工作线程调用——
//  主线程一睡，低级钩子就可能被系统摘除。
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

/// 读模式 UIA 取词（仅 UIA，不动剪贴板；主线程）。
std::optional<Capture> UIAReadSelection();

/// 写模式 UIA 取词：有选区取选区；无选区取整个输入框（主线程）。
std::optional<Capture> UIACaptureForRewrite();

/// 仅通过 UIA 读当前选区（划词监听用；主线程）。
std::optional<Capture> UIASelectionOnly();

/// 模拟 Ctrl+C 复制兜底，用后还原剪贴板（阻塞 ≤400ms，工作线程调用）。
std::optional<std::wstring> ClipboardFallbackCopy();

/// 兜底锚点：光标位置一小块矩形
RECT CursorAnchor();

} // namespace capture
