#include "SelectionIcon.h"
#include "BrandMark.h"
#include "Hooks.h"
#include <dwmapi.h>
#include <algorithm>

namespace {
constexpr wchar_t kClassName[] = L"TypeTideSelectionIcon";
constexpr UINT_PTR kAutoHideTimer = 1;
constexpr BYTE kAccentRed = 0x7C;
constexpr BYTE kAccentGreen = 0x5C;
constexpr BYTE kAccentBlue = 0xFF;
} // namespace

SelectionIcon& SelectionIcon::shared() {
    static SelectionIcon icon;
    return icon;
}

LRESULT CALLBACK SelectionIcon::wndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    SelectionIcon* self = (SelectionIcon*)GetWindowLongPtrW(hwnd, GWLP_USERDATA);
    if (msg == WM_NCCREATE) {
        auto* cs = (CREATESTRUCTW*)lp;
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)cs->lpCreateParams);
        return DefWindowProcW(hwnd, msg, wp, lp);
    }
    if (!self) return DefWindowProcW(hwnd, msg, wp, lp);
    return self->handle(msg, wp, lp);
}

void SelectionIcon::show(RECT selectionRect, bool rectValid, POINT fallback, std::function<void()> onTap) {
    hide();
    onTap_ = std::move(onTap);

    static bool registered = [] {
        WNDCLASSW wc{};
        wc.lpfnWndProc = wndProc;
        wc.hInstance = GetModuleHandleW(nullptr);
        wc.lpszClassName = kClassName;
        wc.hCursor = LoadCursorW(nullptr, IDC_HAND);
        RegisterClassW(&wc);
        return true;
    }();
    (void)registered;

    UINT dpi = GetDpiForSystem();
    int size = MulDiv(28, (int)dpi, 96);

    POINT origin;
    if (rectValid && selectionRect.right - selectionRect.left > 2) {
        origin = {selectionRect.right + 6, (selectionRect.top + selectionRect.bottom) / 2 - size / 2};
    } else {
        origin = {fallback.x + 6, fallback.y + 6};
    }

    // 夹到所在显示器工作区内
    HMONITOR mon = MonitorFromPoint(origin, MONITOR_DEFAULTTONEAREST);
    MONITORINFO mi{sizeof(mi)};
    GetMonitorInfoW(mon, &mi);
    origin.x = std::max(mi.rcWork.left + 4, std::min(origin.x, mi.rcWork.right - size - 4));
    origin.y = std::max(mi.rcWork.top + 4, std::min(origin.y, mi.rcWork.bottom - size - 4));

    hwnd_ = CreateWindowExW(WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
                            kClassName, L"", WS_POPUP,
                            origin.x, origin.y, size, size,
                            nullptr, nullptr, GetModuleHandleW(nullptr), this);
    if (!hwnd_) return;

    DWM_WINDOW_CORNER_PREFERENCE corner = DWMWCP_ROUNDSMALL;
    DwmSetWindowAttribute(hwnd_, DWMWA_WINDOW_CORNER_PREFERENCE, &corner, sizeof(corner));

    ShowWindow(hwnd_, SW_SHOWNOACTIVATE);
    SetTimer(hwnd_, kAutoHideTimer, 3000, nullptr);

    // 点击别处即消失
    mouseHookId_ = hooks::AddMouse([this](WPARAM event, POINT pt) {
        if (event != WM_LBUTTONDOWN && event != WM_RBUTTONDOWN) return;
        if (!hwnd_) return;
        RECT wr{};
        GetWindowRect(hwnd_, &wr);
        if (!PtInRect(&wr, pt)) hide();
    });
}

void SelectionIcon::hide() {
    if (mouseHookId_) {
        hooks::RemoveMouse(mouseHookId_);
        mouseHookId_ = 0;
    }
    if (hwnd_) {
        HWND h = hwnd_;
        hwnd_ = nullptr;
        DestroyWindow(h);
    }
}

bool SelectionIcon::containsScreenPoint(POINT pt) const {
    if (!hwnd_) return false;
    RECT wr{};
    GetWindowRect(hwnd_, &wr);
    return PtInRect(&wr, pt);
}

LRESULT SelectionIcon::handle(UINT msg, WPARAM wp, LPARAM lp) {
    (void)lp;
    switch (msg) {
    case WM_PAINT: {
        PAINTSTRUCT ps;
        HDC dc = BeginPaint(hwnd_, &ps);
        RECT rc{};
        GetClientRect(hwnd_, &rc);
        int boost = hover_ ? 18 : 0;
        auto brighten = [boost](BYTE channel) {
            return static_cast<BYTE>(std::min(255, static_cast<int>(channel) + boost));
        };
        HBRUSH bg = CreateSolidBrush(RGB(brighten(kAccentRed),
                                         brighten(kAccentGreen),
                                         brighten(kAccentBlue)));
        FillRect(dc, &rc, bg);
        DeleteObject(bg);
        UINT dpi = GetDpiForWindow(hwnd_);
        const int inset = MulDiv(4, (int)dpi, 96);
        RECT mark{rc.left + inset, rc.top + inset, rc.right - inset, rc.bottom - inset};
        brand::DrawMark(dc, mark, RGB(255, 255, 255));
        EndPaint(hwnd_, &ps);
        return 0;
    }
    case WM_MOUSEMOVE:
        if (!hover_) {
            hover_ = true;
            InvalidateRect(hwnd_, nullptr, TRUE);
            TRACKMOUSEEVENT tme{sizeof(tme), TME_LEAVE, hwnd_, 0};
            TrackMouseEvent(&tme);
        }
        return 0;
    case WM_MOUSELEAVE:
        hover_ = false;
        if (hwnd_) InvalidateRect(hwnd_, nullptr, TRUE);
        return 0;
    case WM_LBUTTONDOWN: {
        auto tap = onTap_;
        hide();
        if (tap) tap();
        return 0;
    }
    case WM_TIMER:
        if (wp == kAutoHideTimer) hide();
        return 0;
    case WM_MOUSEACTIVATE:
        return MA_NOACTIVATE;
    }
    return DefWindowProcW(hwnd_, msg, wp, lp);
}
