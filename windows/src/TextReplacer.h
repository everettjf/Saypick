//
//  TextReplacer.h — 原地替换：合成 Ctrl+V 粘贴，保留撤销栈；用后还原剪贴板。
//
//  在专属工作线程执行（内部有等待，主线程不能睡——低级钩子会被摘）。
//  剪贴板用延迟渲染（WM_RENDERFORMAT）：目标应用真正取走粘贴内容时才知道
//  粘贴发生了，再还原剪贴板——比赌固定延迟可靠。
//
#pragma once
#include <string>

namespace replacer {

/// 用译文替换（异步，立即返回）。selectAll=true 时先 Ctrl+A 全选（整框改写）。
void ReplaceAsync(std::wstring text, bool selectAll);

} // namespace replacer
