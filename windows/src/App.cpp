#include "App.h"
#include "Hooks.h"
#include "PopupWindow.h"
#include "SelectionIcon.h"
#include "SelectionMonitor.h"
#include "Settings.h"
#include "SettingsWindow.h"
#include "TextReplacer.h"
#include "Translator.h"
#include "UpdateChecker.h"
#include "Util.h"
#include <shellapi.h>
#include <psapi.h>
#include <thread>

namespace {
constexpr int kReadHotkeyId = 1;
constexpr int kRewriteHotkeyId = 2;
} // namespace

App& App::shared() {
    static App app;
    return app;
}

LRESULT CALLBACK App::wndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if (msg == WM_CREATE) return 0;
    App& self = App::shared();
    if (self.hwnd_ == nullptr || hwnd == self.hwnd_) {
        self.hwnd_ = hwnd;
        return self.handle(msg, wp, lp);
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

bool App::init(HINSTANCE inst) {
    WNDCLASSW wc{};
    wc.lpfnWndProc = wndProc;
    wc.hInstance = inst;
    wc.lpszClassName = kAppWindowClass;
    RegisterClassW(&wc);

    // 隐藏主窗口（顶层不可见；托盘与热键的宿主）
    hwnd_ = CreateWindowExW(0, kAppWindowClass, L"Saypick", 0, 0, 0, 0, 0,
                            nullptr, nullptr, inst, nullptr);
    if (!hwnd_) return false;

    tray_.onToggleEnabled = [this] {
        Settings& s = Settings::shared();
        s.enabled = !s.enabled;
        s.save();
        applyEnabledState();
    };
    tray_.onOpenSettings = [this] { openSettings(); };
    tray_.onOpenReleases = [] { updatechecker::OpenReleasesPage(); };
    tray_.onQuit = [this] { quit(); };
    tray_.add(hwnd_, WM_APP_TRAY);

    applyEnabledState();

    // 首次启动：打开设置窗口，让用户立刻完成配置
    Settings& s = Settings::shared();
    if (!s.hasCompletedFirstLaunch) {
        s.hasCompletedFirstLaunch = true;
        s.save();
        openSettings();
    }

    updatechecker::CheckIfDue(hwnd_, WM_APP_UPDATE);
    return true;
}

void App::applyEnabledState() {
    UnregisterHotKey(hwnd_, kReadHotkeyId);
    UnregisterHotKey(hwnd_, kRewriteHotkeyId);
    SelectionMonitor::shared().stop();
    SelectionIcon::shared().hide();

    const Settings& s = Settings::shared();
    if (!s.enabled) return;

    bool ok1 = RegisterHotKey(hwnd_, kReadHotkeyId,
                              s.readShortcut.modifiers | MOD_NOREPEAT, s.readShortcut.vk);
    bool ok2 = RegisterHotKey(hwnd_, kRewriteHotkeyId,
                              s.rewriteShortcut.modifiers | MOD_NOREPEAT, s.rewriteShortcut.vk);
    if ((!ok1 || !ok2) && !hotkeyWarningShown_) {
        hotkeyWarningShown_ = true;
        MessageBoxW(nullptr,
                    L"Another application already uses one of Saypick's shortcuts.\n"
                    L"Pick a different one in Settings → Shortcuts.",
                    L"Saypick — shortcut unavailable", MB_OK | MB_ICONWARNING);
    }

    setupSelectionTrigger();
}

void App::setupSelectionTrigger() {
    const Settings& s = Settings::shared();
    if (s.selectionTrigger == SelectionTrigger::None) return;

    SelectionMonitor::shared().onSelection = [this](const capture::Capture& cap, POINT mouse) {
        const Settings& st = Settings::shared();
        if (!st.enabled || foregroundAppSkipped()) return;
        if (st.selectionTrigger == SelectionTrigger::Icon) {
            capture::Capture copy = cap;
            SelectionIcon::shared().show(cap.anchor, cap.hasAnchor, mouse,
                                         [this, copy] { presentRead(copy); });
        } else if (st.selectionTrigger == SelectionTrigger::Auto) {
            presentRead(cap);
        }
    };
    SelectionMonitor::shared().start();
}

void App::openSettings() {
    SettingsWindow::open(hwnd_);
}

void App::quit() {
    PopupWindow::shared().close();
    SelectionIcon::shared().hide();
    SelectionMonitor::shared().stop();
    tray_.remove();
    PostQuitMessage(0);
}

// ---------- 方向决策（与 macOS resolveDirection 一致）----------

App::Direction App::resolveDirection(const std::wstring& text, TranslationDirection mode, bool isWrite) const {
    const Settings& s = Settings::shared();
    Language native = s.nativeLanguage;
    Language foreign = s.foreignLanguage;
    switch (mode) {
    case TranslationDirection::NativeToForeign:
        return {native, foreign};
    case TranslationDirection::ForeignToNative:
        return {foreign, native};
    case TranslationDirection::Auto:
    default: {
        std::optional<Language> detected = lang::Detect(text);
        Language to;
        if (detected == native) to = foreign;
        else if (detected == foreign) to = native;
        else to = isWrite ? foreign : native;
        return {detected, to};
    }
    }
}

// ---------- 跳过列表 ----------

bool App::foregroundAppSkipped() const {
    const Settings& s = Settings::shared();
    if (s.skipApps.empty()) return false;

    HWND fg = GetForegroundWindow();
    if (!fg) return false;
    DWORD pid = 0;
    GetWindowThreadProcessId(fg, &pid);
    if (!pid) return false;
    HANDLE proc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!proc) return false;
    wchar_t path[MAX_PATH]{};
    DWORD size = MAX_PATH;
    bool got = QueryFullProcessImageNameW(proc, 0, path, &size);
    CloseHandle(proc);
    if (!got) return false;

    std::wstring exe = path;
    auto slash = exe.find_last_of(L"\\/");
    if (slash != std::wstring::npos) exe = exe.substr(slash + 1);
    std::wstring exeLower = util::ToLower(exe);
    std::wstring exeNoExt = exeLower;
    if (exeNoExt.size() > 4 && exeNoExt.rfind(L".exe") == exeNoExt.size() - 4)
        exeNoExt.resize(exeNoExt.size() - 4);

    for (const auto& entry : s.skipApps) {
        std::wstring e = util::ToLower(util::Trim(entry));
        if (e.empty()) continue;
        if (e.size() > 4 && e.rfind(L".exe") == e.size() - 4) e.resize(e.size() - 4);
        if (e == exeNoExt) return true;
    }
    return false;
}

// ---------- 读·划词翻译 ----------

void App::handleRead() {
    const Settings& s = Settings::shared();
    util::Log("handleRead enabled=%d", s.enabled);
    if (!s.enabled || foregroundAppSkipped()) return;
    auto cap = capture::ReadSelection();
    util::Log("handleRead capture=%d text_len=%d hasAnchor=%d",
              cap.has_value(), cap ? (int)cap->text.size() : -1, cap ? cap->hasAnchor : 0);
    if (!cap) return;
    presentRead(*cap);
}

void App::presentRead(const capture::Capture& cap) {
    const Settings& s = Settings::shared();
    RECT anchor = cap.hasAnchor ? cap.anchor : capture::CursorAnchor();
    Direction dir = resolveDirection(cap.text, s.readDirection, false);

    currentSource_ = dir.from;
    currentText_ = cap.text;
    currentStyle_ = s.readStyle;
    currentReplaceSelectAll_ = false;

    PopupWindow& popup = PopupWindow::shared();
    popup.show(cap.text, dir.to, anchor, /*showReplace=*/true);
    popup.onReplace = [this] {
        std::wstring t = PopupWindow::shared().translation();
        if (util::Trim(t).empty()) return;
        bool selectAll = currentReplaceSelectAll_;
        PopupWindow::shared().close();
        replacer::Replace(t, selectAll);
    };
    popup.onRetarget = [this](Language newTarget) {
        translator::Cancel(currentReq_);
        PopupWindow& p = PopupWindow::shared();
        p.setTarget(newTarget);
        p.resetForRetranslate();
        startStream(currentText_, currentSource_, newTarget, currentStyle_);
    };
    popup.onClosed = [this] { translator::Cancel(currentReq_); };

    startStream(cap.text, dir.from, dir.to, s.readStyle);
}

void App::startStream(const std::wstring& text, std::optional<Language> from, Language to, RewriteStyle style) {
    HWND hwnd = hwnd_;
    currentReq_ = translator::Stream(
        {text, from, to, style},
        [hwnd](uint64_t id, const std::wstring& delta) {
            PostMessageW(hwnd, WM_APP_TR_DELTA, (WPARAM)id, (LPARAM) new std::wstring(delta));
        },
        [hwnd](uint64_t id, bool ok, const std::wstring& error) {
            PostMessageW(hwnd, WM_APP_TR_DONE, (WPARAM)id, (LPARAM) new DoneMsg{ok, error});
        });
}

// ---------- 写·输入改写 ----------

void App::handleRewrite() {
    const Settings& s = Settings::shared();
    if (!s.enabled || foregroundAppSkipped()) return;
    auto cap = capture::CaptureForRewrite();
    if (!cap) return;

    Direction dir = resolveDirection(cap->text, s.rewriteDirection, true);

    if (s.rewritePreview) {
        // 先预览：弹窗显示译文 + Replace（整框改写替换时先全选）
        RECT anchor = cap->hasAnchor ? cap->anchor : capture::CursorAnchor();
        currentSource_ = dir.from;
        currentText_ = cap->text;
        currentStyle_ = s.rewriteStyle;
        currentReplaceSelectAll_ = cap->isWholeField;

        PopupWindow& popup = PopupWindow::shared();
        popup.show(cap->text, dir.to, anchor, /*showReplace=*/true);
        popup.onReplace = [this] {
            std::wstring t = PopupWindow::shared().translation();
            if (util::Trim(t).empty()) return;
            bool selectAll = currentReplaceSelectAll_;
            PopupWindow::shared().close();
            replacer::Replace(t, selectAll);
        };
        popup.onRetarget = [this](Language newTarget) {
            translator::Cancel(currentReq_);
            PopupWindow& p = PopupWindow::shared();
            p.setTarget(newTarget);
            p.resetForRetranslate();
            startStream(currentText_, currentSource_, newTarget, currentStyle_);
        };
        popup.onClosed = [this] { translator::Cancel(currentReq_); };

        startStream(cap->text, dir.from, dir.to, s.rewriteStyle);
    } else {
        // 直接替换：后台完整翻译 → 回主线程粘贴
        HWND hwnd = hwnd_;
        capture::Capture c = *cap;
        Direction d = dir;
        RewriteStyle style = s.rewriteStyle;
        std::thread([hwnd, c, d, style] {
            std::wstring err;
            auto result = translator::TranslateFully({c.text, d.from, d.to, style}, &err);
            auto* msg = new RewriteResult{
                result.has_value(),
                result.value_or(L""),
                err,
                c.isWholeField,
                c.hasAnchor ? c.anchor : capture::CursorAnchor(),
                true,
                c.text,
                d.to,
            };
            PostMessageW(hwnd, WM_APP_REWRITE_DONE, 0, (LPARAM)msg);
        }).detach();
    }
}

void App::showErrorPopup(const std::wstring& original, Language target, RECT anchor, const std::wstring& error) {
    PopupWindow& popup = PopupWindow::shared();
    popup.show(original, target, anchor, /*showReplace=*/false);
    popup.onReplace = nullptr;
    popup.onRetarget = nullptr;
    popup.onClosed = nullptr;
    popup.setError(error);
}

// ---------- 消息处理 ----------

LRESULT App::handle(UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
    case WM_HOTKEY:
        if (wp == kReadHotkeyId) handleRead();
        else if (wp == kRewriteHotkeyId) handleRewrite();
        return 0;

    case WM_APP_TRAY: {
        UINT event = LOWORD(lp);
        if (event == WM_CONTEXTMENU || event == WM_RBUTTONUP || event == WM_LBUTTONUP)
            tray_.showMenu(hwnd_);
        else if (event == WM_LBUTTONDBLCLK)
            openSettings();
        return 0;
    }

    case WM_APP_TR_DELTA: {
        auto* delta = (std::wstring*)lp;
        if ((uint64_t)wp == currentReq_ && PopupWindow::shared().isVisible())
            PopupWindow::shared().appendDelta(*delta);
        delete delta;
        return 0;
    }

    case WM_APP_TR_DONE: {
        auto* done = (DoneMsg*)lp;
        if ((uint64_t)wp == currentReq_ && PopupWindow::shared().isVisible()) {
            if (!done->ok)
                PopupWindow::shared().setError(done->error);
            else if (util::Trim(PopupWindow::shared().translation()).empty())
                PopupWindow::shared().setError(L"No translation returned");
        }
        delete done;
        return 0;
    }

    case WM_APP_REWRITE_DONE: {
        auto* r = (RewriteResult*)lp;
        if (r->ok)
            replacer::Replace(r->text, r->isWholeField);
        else
            showErrorPopup(r->original, r->target, r->anchor, r->error);
        delete r;
        return 0;
    }

    case WM_APP_UPDATE:
        tray_.setUpdateAvailable(true);
        return 0;

    case WM_APP_OPEN_SETTINGS:
        openSettings();
        return 0;

    case WM_DESTROY:
        tray_.remove();
        return 0;
    }
    return DefWindowProcW(hwnd_, msg, wp, lp);
}
