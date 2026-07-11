//
//  Hooks.h — 共享的低级鼠标/键盘钩子（多个订阅者复用一个钩子）。
//  回调在安装线程（主线程）上触发；回调必须快速返回。
//
#pragma once
#include <windows.h>
#include <functional>

namespace hooks {

/// 鼠标事件（wParam = WM_LBUTTONDOWN/WM_LBUTTONUP/WM_RBUTTONDOWN…，pt = 屏幕坐标）
using MouseFn = std::function<void(WPARAM event, POINT pt)>;
int AddMouse(MouseFn fn);
void RemoveMouse(int id);

/// 键盘按下事件；返回 true 表示吞掉该键
using KeyFn = std::function<bool(DWORD vk)>;
int AddKey(KeyFn fn);
void RemoveKey(int id);

} // namespace hooks
