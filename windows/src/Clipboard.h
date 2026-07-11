//
//  Clipboard.h — 文本剪贴板读写与快照/还原（对应 macOS 的 Pasteboard）。
//
#pragma once
#include <windows.h>
#include <optional>
#include <string>

namespace clipboard {

/// 当前剪贴板文本；非文本或为空返回 nullopt
std::optional<std::wstring> GetText();

/// 写入文本
bool SetText(const std::wstring& text);

/// 剪贴板序列号（变化说明有新内容写入）
DWORD SequenceNumber();

/// 文本快照。非文本内容不保存（还原时清空），与 macOS 侧行为一致：
/// 我们只承诺还原文本。
struct Snapshot {
    std::optional<std::wstring> text;
};

Snapshot Take();
void Restore(const Snapshot& snap);

} // namespace clipboard
