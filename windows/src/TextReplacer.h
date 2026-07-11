//
//  TextReplacer.h — 原地替换：合成 Ctrl+V 粘贴，保留撤销栈；用后还原剪贴板。
//
#pragma once
#include <string>

namespace replacer {

/// 用译文替换。selectAll=true 时先 Ctrl+A 全选（整框改写），否则直接粘到当前选区。
/// 阻塞约 200ms（等目标应用完成粘贴再还原剪贴板）。
void Replace(const std::wstring& text, bool selectAll);

} // namespace replacer
