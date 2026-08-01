#include "PopupWindow.h"
#include "Clipboard.h"
#include "Hooks.h"
#include "Util.h"
#include <dwmapi.h>
#include <windowsx.h>
#include <algorithm>

namespace {

constexpr wchar_t kClassName[] = L"TypeTidePopup";
constexpr UINT_PTR kCopiedTimer = 1;

// 品牌紫（与 README badge 一致）
constexpr COLORREF kAccent = RGB(0x7C, 0x5C, 0xFF);
constexpr COLORREF kAccentText = RGB(255, 255, 255);

bool systemPrefersDark() {
    DWORD v = 1, size = sizeof(v);
    RegGetValueW(HKEY_CURRENT_USER,
                 L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
                 L"AppsUseLightTheme", RRF_RT_REG_DWORD, nullptr, &v, &size);
    return v == 0;
}

struct Theme {
    COLORREF bg, text, secondary, divider, buttonBg, buttonBorder, error;
};

Theme themeFor(bool dark) {
    if (dark)
        return {RGB(0x2B, 0x2B, 0x2E), RGB(0xF2, 0xF2, 0xF2), RGB(0x9A, 0x9A, 0xA0),
                RGB(0x45, 0x45, 0x4A), RGB(0x3A, 0x3A, 0x3F), RGB(0x55, 0x55, 0x5A),
                RGB(0xFF, 0xA5, 0x4C)};
    return {RGB(0xFF, 0xFF, 0xFF), RGB(0x1D, 0x1D, 0x1F), RGB(0x71, 0x71, 0x76),
            RGB(0xE4, 0xE4, 0xE8), RGB(0xF2, 0xF2, 0xF5), RGB(0xD5, 0xD5, 0xDA),
            RGB(0xD9, 0x77, 0x06)};
}

} // namespace

PopupWindow& PopupWindow::shared() {
    static PopupWindow p;
    return p;
}

LRESULT CALLBACK PopupWindow::wndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    PopupWindow* self = (PopupWindow*)GetWindowLongPtrW(hwnd, GWLP_USERDATA);
    if (msg == WM_NCCREATE) {
        auto* cs = (CREATESTRUCTW*)lp;
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)cs->lpCreateParams);
        return DefWindowProcW(hwnd, msg, wp, lp);
    }
    if (!self) return DefWindowProcW(hwnd, msg, wp, lp);
    return self->handle(msg, wp, lp);
}

void PopupWindow::show(const std::wstring& original, Language target, RECT anchor, bool showReplace) {
    close();

    original_ = original;
    translation_.clear();
    error_.clear();
    loading_ = true;
    copiedFlash_ = false;
    scrollY_ = 0;
    target_ = target;
    anchor_ = anchor;
    showReplace_ = showReplace;
    hover_ = Region::None;
    dark_ = systemPrefersDark();

    static bool registered = [] {
        WNDCLASSW wc{};
        wc.lpfnWndProc = wndProc;
        wc.hInstance = GetModuleHandleW(nullptr);
        wc.lpszClassName = kClassName;
        wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
        RegisterClassW(&wc);
        return true;
    }();
    (void)registered;

    hwnd_ = CreateWindowExW(WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
                            kClassName, L"TypeTide", WS_POPUP,
                            0, 0, 10, 10, nullptr, nullptr, GetModuleHandleW(nullptr), this);
    util::Log("popup show hwnd=%p", (void*)hwnd_);
    if (!hwnd_) return;

    dpi_ = GetDpiForWindow(hwnd_);
    updateFonts();

    // Win11 圆角
    DWM_WINDOW_CORNER_PREFERENCE corner = DWMWCP_ROUND;
    DwmSetWindowAttribute(hwnd_, DWMWA_WINDOW_CORNER_PREFERENCE, &corner, sizeof(corner));
    BOOL darkAttr = dark_;
    DwmSetWindowAttribute(hwnd_, DWMWA_USE_IMMERSIVE_DARK_MODE, &darkAttr, sizeof(darkAttr));

    placedAbove_ = false;
    layoutAndResize();
    ShowWindow(hwnd_, SW_SHOWNOACTIVATE);
    installDismissMonitors();
}

void PopupWindow::close() {
    if (!hwnd_) return;
    removeDismissMonitors();
    HWND h = hwnd_;
    hwnd_ = nullptr;
    DestroyWindow(h);
    if (onClosed) onClosed();
}

void PopupWindow::appendDelta(const std::wstring& delta) {
    if (!hwnd_) return;
    translation_ += delta;
    loading_ = false;
    layoutAndResize();
    InvalidateRect(hwnd_, nullptr, TRUE);
}

void PopupWindow::setError(const std::wstring& error) {
    if (!hwnd_) return;
    error_ = error;
    loading_ = false;
    layoutAndResize();
    InvalidateRect(hwnd_, nullptr, TRUE);
}

void PopupWindow::setTarget(Language target) {
    target_ = target;
    if (hwnd_) InvalidateRect(hwnd_, nullptr, TRUE);
}

void PopupWindow::resetForRetranslate() {
    if (!hwnd_) return;
    translation_.clear();
    error_.clear();
    loading_ = true;
    layoutAndResize();
    InvalidateRect(hwnd_, nullptr, TRUE);
}

void PopupWindow::updateFonts() {
    if (fontHeader_) DeleteObject(fontHeader_);
    if (fontBody_) DeleteObject(fontBody_);
    if (fontSmall_) DeleteObject(fontSmall_);
    auto make = [&](int pt, int weight) {
        return CreateFontW(-MulDiv(pt, (int)dpi_, 72), 0, 0, 0, weight, FALSE, FALSE, FALSE,
                           DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                           CLEARTYPE_QUALITY, DEFAULT_PITCH, L"Segoe UI");
    };
    fontHeader_ = make(9, FW_SEMIBOLD);
    fontBody_ = make(11, FW_NORMAL);
    fontSmall_ = make(9, FW_NORMAL);
}

void PopupWindow::layoutAndResize() {
    if (!hwnd_) return;
    const int s100 = (int)dpi_;
    auto px = [&](int v) { return MulDiv(v, s100, 96); };

    HMONITOR sizeMon = MonitorFromRect(&anchor_, MONITOR_DEFAULTTONEAREST);
    MONITORINFO sizeInfo{sizeof(sizeInfo)};
    GetMonitorInfoW(sizeMon, &sizeInfo);
    const int workWidth = sizeInfo.rcWork.right - sizeInfo.rcWork.left;
    width_ = std::clamp(workWidth / 3, px(360), px(520));
    const int width = width_;
    const int headerH = px(34);
    const int padX = px(14);
    const int padY = px(12);
    const int contentW = width - padX * 2;

    // 正文高度
    HDC dc = GetDC(hwnd_);
    HFONT old = (HFONT)SelectObject(dc, fontBody_);
    std::wstring bodyText = !error_.empty() ? error_
                          : (translation_.empty() && loading_) ? L"Translating…"
                          : translation_;
    RECT rc{0, 0, contentW, 0};
    DrawTextW(dc, bodyText.c_str(), -1, &rc, DT_WORDBREAK | DT_CALCRECT);
    SelectObject(dc, old);
    ReleaseDC(hwnd_, dc);
    textHeight_ = rc.bottom > px(20) ? rc.bottom : px(20);
    int textH = textHeight_;

    // 高度钳制：正文最多占所在显示器工作区的 60%，超出部分画省略号
    // （Copy 复制的仍是完整译文）
    {
        HMONITOR monClamp = MonitorFromRect(&anchor_, MONITOR_DEFAULTTONEAREST);
        MONITORINFO miClamp{sizeof(miClamp)};
        GetMonitorInfoW(monClamp, &miClamp);
        int maxTextH = (miClamp.rcWork.bottom - miClamp.rcWork.top) * 6 / 10;
        if (textH > maxTextH) textH = maxTextH;
    }
    viewportHeight_ = textH;
    scrollY_ = std::clamp(scrollY_, 0, std::max(0, textHeight_ - viewportHeight_));

    bool hasButtons = (!translation_.empty() && error_.empty()) ||
                      (!error_.empty() && static_cast<bool>(onRetry));
    const int btnH = px(32);
    const int btnGap = px(10);

    int height = headerH + 1 + padY + textH + (hasButtons ? btnGap + btnH : 0) + padY;

    // 命中区域
    const int chipH = px(20);
    rcClose_ = {width - padX - px(32), (headerH - px(32)) / 2,
                width - padX, (headerH + px(32)) / 2};
    int langW = px(86);
    rcLang_ = {rcClose_.left - px(10) - langW, (headerH - chipH) / 2, rcClose_.left - px(10), (headerH + chipH) / 2};

    int btnY = height - padY - btnH;
    int replaceW = showReplace_ ? px(84) : 0;
    int copyW = px(70);
    if (!error_.empty() && onRetry) {
        rcCopy_ = rcReplace_ = RECT{};
        rcRetry_ = {width - padX - px(76), btnY, width - padX, btnY + btnH};
    } else if (hasButtons) {
        rcRetry_ = {};
        int x = width - padX;
        if (showReplace_) {
            rcReplace_ = {x - replaceW, btnY, x, btnY + btnH};
            x = rcReplace_.left - px(10);
        } else {
            rcReplace_ = {};
        }
        rcCopy_ = {x - copyW, btnY, x, btnY + btnH};
    } else {
        rcCopy_ = rcReplace_ = rcRetry_ = RECT{};
    }

    // 定位：优先锚点下方，放不下改上方；夹在锚点所在显示器工作区内
    HMONITOR mon = MonitorFromRect(&anchor_, MONITOR_DEFAULTTONEAREST);
    MONITORINFO mi{sizeof(mi)};
    GetMonitorInfoW(mon, &mi);
    const RECT& wa = mi.rcWork;

    int x = anchor_.left;
    int y;
    if (!placedAbove_) {
        y = anchor_.bottom + px(8);
        if (y + height > wa.bottom - px(8)) placedAbove_ = true;
    }
    if (placedAbove_) {
        y = anchor_.top - px(8) - height;
        if (y < wa.top + px(8)) y = wa.top + px(8);
    }
    x = std::max((int)wa.left + px(8), std::min(x, (int)wa.right - width - px(8)));
    y = std::max((int)wa.top + px(8), std::min(y, (int)wa.bottom - height - px(8)));

    SetWindowPos(hwnd_, HWND_TOPMOST, x, y, width, height, SWP_NOACTIVATE);
}

void PopupWindow::paint(HDC dc) {
    RECT client{};
    GetClientRect(hwnd_, &client);
    Theme th = themeFor(dark_);
    auto px = [&](int v) { return MulDiv(v, (int)dpi_, 96); };

    // 背景 + 边框
    HBRUSH bg = CreateSolidBrush(th.bg);
    FillRect(dc, &client, bg);
    DeleteObject(bg);
    HBRUSH border = CreateSolidBrush(th.divider);
    FrameRect(dc, &client, border);
    DeleteObject(border);

    SetBkMode(dc, TRANSPARENT);
    const int headerH = px(34);
    const int padX = px(14);
    const int padY = px(12);

    // ---- 头部 ----
    SelectObject(dc, fontHeader_);
    SetTextColor(dc, kAccent);
    RECT rcBrand{padX, 0, client.right, headerH};
    DrawTextW(dc, L"❖", -1, &rcBrand, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
    SetTextColor(dc, th.secondary);
    rcBrand.left += px(16);
    DrawTextW(dc, L"TypeTide", -1, &rcBrand, DT_SINGLELINE | DT_VCENTER);

    // 目标语言 chip
    {
        HBRUSH chipBg = CreateSolidBrush(hover_ == Region::Lang ? th.buttonBg : th.bg);
        FillRect(dc, &rcLang_, chipBg);
        DeleteObject(chipBg);
        SelectObject(dc, fontSmall_);
        SetTextColor(dc, th.secondary);
        std::wstring label = L"🌐 " + lang::ShortName(target_) + L" ▾";
        DrawTextW(dc, label.c_str(), -1, (RECT*)&rcLang_,
                  DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
    }

    // 关闭按钮
    SelectObject(dc, fontSmall_);
    SetTextColor(dc, hover_ == Region::Close ? th.text : th.secondary);
    DrawTextW(dc, L"✕", -1, (RECT*)&rcClose_, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);

    // 分隔线
    RECT divider{0, headerH, client.right, headerH + 1};
    HBRUSH divBrush = CreateSolidBrush(th.divider);
    FillRect(dc, &divider, divBrush);
    DeleteObject(divBrush);

    // ---- 正文 ----
    SelectObject(dc, fontBody_);
    int textBottom = headerH + 1 + padY + viewportHeight_;
    RECT clipText{padX, headerH + 1 + padY, client.right - padX, textBottom};
    int saved = SaveDC(dc);
    IntersectClipRect(dc, clipText.left, clipText.top, clipText.right, clipText.bottom);
    RECT rcText{padX, headerH + 1 + padY - scrollY_, client.right - padX,
                headerH + 1 + padY - scrollY_ + textHeight_};
    if (!error_.empty()) {
        SetTextColor(dc, th.error);
        std::wstring msg = L"⚠ " + error_;
        DrawTextW(dc, msg.c_str(), -1, &rcText, DT_WORDBREAK | DT_NOPREFIX);
    } else if (translation_.empty() && loading_) {
        SetTextColor(dc, th.secondary);
        DrawTextW(dc, L"Translating…", -1, &rcText, DT_WORDBREAK);
    } else {
        SetTextColor(dc, th.text);
        DrawTextW(dc, translation_.c_str(), -1, &rcText,
                  DT_WORDBREAK | DT_NOPREFIX | DT_EDITCONTROL);
    }
    RestoreDC(dc, saved);
    if (textHeight_ > viewportHeight_) {
        const int trackTop = headerH + 1 + padY;
        const int trackH = viewportHeight_;
        const int thumbH = std::max(px(24), trackH * viewportHeight_ / textHeight_);
        const int maxScroll = textHeight_ - viewportHeight_;
        const int thumbY = trackTop + (trackH - thumbH) * scrollY_ / std::max(1, maxScroll);
        RECT thumb{client.right - px(5), thumbY, client.right - px(2), thumbY + thumbH};
        HBRUSH sb = CreateSolidBrush(th.buttonBorder);
        FillRect(dc, &thumb, sb);
        DeleteObject(sb);
    }

    // ---- 按钮 ----
    auto drawButton = [&](const RECT& r, const wchar_t* label, bool prominent, bool hovered) {
        if (r.right <= r.left) return;
        COLORREF fill = prominent ? kAccent : th.buttonBg;
        if (hovered) {
            // 悬停微调亮度
            int rr = GetRValue(fill), gg = GetGValue(fill), bb = GetBValue(fill);
            int up = prominent ? 20 : 10;
            fill = RGB(std::min(255, rr + up), std::min(255, gg + up), std::min(255, bb + up));
        }
        HBRUSH b = CreateSolidBrush(fill);
        FillRect(dc, &r, b);
        DeleteObject(b);
        if (!prominent) {
            HBRUSH br = CreateSolidBrush(th.buttonBorder);
            FrameRect(dc, &r, br);
            DeleteObject(br);
        }
        SelectObject(dc, fontSmall_);
        SetTextColor(dc, prominent ? kAccentText : th.text);
        DrawTextW(dc, label, -1, (RECT*)&r, DT_SINGLELINE | DT_VCENTER | DT_CENTER);
    };
    if (!translation_.empty() && error_.empty()) {
        drawButton(rcCopy_, copiedFlash_ ? L"Copied ✓" : L"Copy", false, hover_ == Region::Copy);
        if (showReplace_) drawButton(rcReplace_, L"Replace", true, hover_ == Region::Replace);
    }
    if (!error_.empty() && onRetry)
        drawButton(rcRetry_, L"Retry", true, hover_ == Region::Retry);
}

PopupWindow::Region PopupWindow::hitTest(POINT pt) const {
    if (PtInRect(&rcClose_, pt)) return Region::Close;
    if (PtInRect(&rcLang_, pt)) return Region::Lang;
    if (rcCopy_.right > rcCopy_.left && PtInRect(&rcCopy_, pt)) return Region::Copy;
    if (showReplace_ && rcReplace_.right > rcReplace_.left && PtInRect(&rcReplace_, pt)) return Region::Replace;
    if (rcRetry_.right > rcRetry_.left && PtInRect(&rcRetry_, pt)) return Region::Retry;
    return Region::None;
}

void PopupWindow::showLangMenu() {
    HMENU menu = CreatePopupMenu();
    for (size_t i = 0; i < std::size(lang::All); ++i) {
        UINT flags = MF_STRING;
        if (lang::All[i] == target_) flags |= MF_CHECKED;
        AppendMenuW(menu, flags, 100 + i, lang::DisplayName(lang::All[i]));
    }
    RECT wr{};
    GetWindowRect(hwnd_, &wr);
    POINT at{wr.left + rcLang_.left, wr.top + rcLang_.bottom};

    // TrackPopupMenu 需要前台窗口才能正常关闭；记录并恢复原前台，
    // 保证 Replace 仍粘贴回目标应用。
    HWND prevFg = GetForegroundWindow();
    menuOpen_ = true;
    SetForegroundWindow(hwnd_);
    UINT cmd = (UINT)TrackPopupMenu(menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_LEFTALIGN | TPM_TOPALIGN,
                                    at.x, at.y, 0, hwnd_, nullptr);
    menuOpen_ = false;
    DestroyMenu(menu);
    if (prevFg && prevFg != hwnd_) SetForegroundWindow(prevFg);

    if (cmd >= 100 && cmd < 100 + std::size(lang::All)) {
        Language chosen = lang::All[cmd - 100];
        if (chosen != target_ && onRetarget) onRetarget(chosen);
    }
}

void PopupWindow::installDismissMonitors() {
    mouseHookId_ = hooks::AddMouse([this](WPARAM event, POINT pt) {
        if (event != WM_LBUTTONDOWN && event != WM_RBUTTONDOWN) return;
        if (!hwnd_ || menuOpen_) return;
        RECT wr{};
        GetWindowRect(hwnd_, &wr);
        if (!PtInRect(&wr, pt)) close();
    });
    keyHookId_ = hooks::AddKey([this](DWORD vk) {
        if (vk == VK_ESCAPE && hwnd_ && !menuOpen_) {
            close();
            return true;
        }
        return false;
    });
}

void PopupWindow::removeDismissMonitors() {
    if (mouseHookId_) hooks::RemoveMouse(mouseHookId_);
    if (keyHookId_) hooks::RemoveKey(keyHookId_);
    mouseHookId_ = keyHookId_ = 0;
}

LRESULT PopupWindow::handle(UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
    case WM_PAINT: {
        PAINTSTRUCT ps;
        HDC dc = BeginPaint(hwnd_, &ps);
        // 双缓冲防闪烁
        RECT rc{};
        GetClientRect(hwnd_, &rc);
        HDC mem = CreateCompatibleDC(dc);
        HBITMAP bmp = CreateCompatibleBitmap(dc, rc.right, rc.bottom);
        HBITMAP oldBmp = (HBITMAP)SelectObject(mem, bmp);
        paint(mem);
        BitBlt(dc, 0, 0, rc.right, rc.bottom, mem, 0, 0, SRCCOPY);
        SelectObject(mem, oldBmp);
        DeleteObject(bmp);
        DeleteDC(mem);
        EndPaint(hwnd_, &ps);
        return 0;
    }
    case WM_ERASEBKGND:
        return 1;
    case WM_MOUSEMOVE: {
        if (!trackingMouse_) {
            TRACKMOUSEEVENT tme{sizeof(tme), TME_LEAVE, hwnd_, 0};
            TrackMouseEvent(&tme);
            trackingMouse_ = true;
        }
        POINT pt{GET_X_LPARAM(lp), GET_Y_LPARAM(lp)};
        Region r = hitTest(pt);
        if (r != hover_) {
            hover_ = r;
            SetCursor(LoadCursorW(nullptr, r == Region::None ? IDC_ARROW : IDC_HAND));
            InvalidateRect(hwnd_, nullptr, FALSE);
        }
        return 0;
    }
    case WM_MOUSELEAVE:
        trackingMouse_ = false;
        if (hover_ != Region::None) {
            hover_ = Region::None;
            InvalidateRect(hwnd_, nullptr, FALSE);
        }
        return 0;
    case WM_LBUTTONDOWN: {
        POINT pt{GET_X_LPARAM(lp), GET_Y_LPARAM(lp)};
        switch (hitTest(pt)) {
        case Region::Close:
            close();
            return 0;
        case Region::Lang:
            showLangMenu();
            return 0;
        case Region::Copy:
            if (!translation_.empty()) {
                clipboard::SetText(translation_);
                copiedFlash_ = true;
                InvalidateRect(hwnd_, nullptr, FALSE);
                SetTimer(hwnd_, kCopiedTimer, 1200, nullptr);
            }
            return 0;
        case Region::Replace:
            if (onReplace) onReplace();
            return 0;
        case Region::Retry:
            if (onRetry) onRetry();
            return 0;
        default:
            return 0;
        }
    }
    case WM_TIMER:
        if (wp == kCopiedTimer) {
            KillTimer(hwnd_, kCopiedTimer);
            copiedFlash_ = false;
            if (hwnd_) InvalidateRect(hwnd_, nullptr, FALSE);
        }
        return 0;
    case WM_MOUSEWHEEL:
        if (textHeight_ > viewportHeight_) {
            int step = MulDiv(36, (int)dpi_, 96);
            scrollY_ = std::clamp(scrollY_ - GET_WHEEL_DELTA_WPARAM(wp) / WHEEL_DELTA * step,
                                  0, textHeight_ - viewportHeight_);
            InvalidateRect(hwnd_, nullptr, FALSE);
        }
        return 0;
    case WM_GETTEXT: {
        // 供测试读取当前译文
        size_t n = std::min(translation_.size(), wp > 0 ? (size_t)wp - 1 : (size_t)0);
        if (wp > 0 && lp) {
            memcpy((wchar_t*)lp, translation_.c_str(), n * sizeof(wchar_t));
            ((wchar_t*)lp)[n] = 0;
        }
        return (LRESULT)n;
    }
    case WM_GETTEXTLENGTH:
        return (LRESULT)translation_.size();
    case WM_MOUSEACTIVATE:
        return MA_NOACTIVATE;
    case WM_DPICHANGED:
        dpi_ = HIWORD(wp);
        updateFonts();
        layoutAndResize();
        InvalidateRect(hwnd_, nullptr, TRUE);
        return 0;
    }
    return DefWindowProcW(hwnd_, msg, wp, lp);
}
