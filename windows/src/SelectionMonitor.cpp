#include "SelectionMonitor.h"
#include "Hooks.h"
#include "PopupWindow.h"
#include "SelectionIcon.h"
#include "Util.h"

namespace {
constexpr wchar_t kClassName[] = L"SaypickSelectionMonitor";
constexpr UINT_PTR kSettleTimer = 1;
} // namespace

SelectionMonitor& SelectionMonitor::shared() {
    static SelectionMonitor m;
    return m;
}

LRESULT CALLBACK SelectionMonitor::wndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if (msg == WM_TIMER && wp == kSettleTimer) {
        KillTimer(hwnd, kSettleTimer);
        shared().checkSelection();
        return 0;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

void SelectionMonitor::start() {
    stop();

    static bool registered = [] {
        WNDCLASSW wc{};
        wc.lpfnWndProc = wndProc;
        wc.hInstance = GetModuleHandleW(nullptr);
        wc.lpszClassName = kClassName;
        RegisterClassW(&wc);
        return true;
    }();
    (void)registered;

    msgWindow_ = CreateWindowExW(0, kClassName, L"", 0, 0, 0, 0, 0,
                                 HWND_MESSAGE, nullptr, GetModuleHandleW(nullptr), nullptr);

    mouseHookId_ = hooks::AddMouse([this](WPARAM event, POINT pt) {
        if (event == WM_LBUTTONUP) handleMouseUp(pt);
    });
}

void SelectionMonitor::stop() {
    if (mouseHookId_) {
        hooks::RemoveMouse(mouseHookId_);
        mouseHookId_ = 0;
    }
    if (msgWindow_) {
        DestroyWindow(msgWindow_);
        msgWindow_ = nullptr;
    }
    lastText_.clear();
}

void SelectionMonitor::handleMouseUp(POINT pt) {
    if (!msgWindow_) return;
    // 点在自家弹窗/图标上不算划词
    if (SelectionIcon::shared().containsScreenPoint(pt)) return;
    if (PopupWindow::shared().isVisible()) return;
    lastMouseUp_ = pt;
    // 等选区稳定（钩子回调里不能久留，交给定时器）
    SetTimer(msgWindow_, kSettleTimer, 150, nullptr);
}

void SelectionMonitor::checkSelection() {
    auto cap = capture::UIASelectionOnly();
    if (!cap) {
        lastText_.clear();
        return;
    }
    std::wstring trimmed = util::Trim(cap->text);
    if (trimmed.empty()) {
        lastText_.clear();
        return;
    }
    // 同一选区不重复触发
    if (trimmed == lastText_) return;
    lastText_ = trimmed;
    if (onSelection) onSelection(*cap, lastMouseUp_);
}
