//
//  SelectionMonitor.h — 全局监听鼠标抬起，检测其他应用里的文字选区
//  （仅 UIA，不动剪贴板；对应 macOS 的 SelectionMonitor）。
//
#pragma once
#include <windows.h>
#include "SelectionCapture.h"
#include <functional>
#include <string>

class SelectionMonitor {
public:
    static SelectionMonitor& shared();

    /// 选区回调：捕获结果（含文字与屏幕矩形）+ 鼠标位置
    std::function<void(const capture::Capture& cap, POINT mouse)> onSelection;

    void start();
    void stop();

private:
    SelectionMonitor() = default;
    static LRESULT CALLBACK wndProc(HWND, UINT, WPARAM, LPARAM);
    void handleMouseUp(POINT pt);
    void checkSelection();

    HWND msgWindow_ = nullptr;  // 定时器载体（message-only window）
    int mouseHookId_ = 0;
    POINT lastMouseUp_{};
    std::wstring lastText_;
};
