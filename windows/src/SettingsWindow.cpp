#include "SettingsWindow.h"
#include "App.h"
#include "LaunchAtLogin.h"
#include "OllamaModels.h"
#include "resource.h"
#include "Settings.h"
#include "UpdateChecker.h"
#include "Util.h"
#include <commctrl.h>
#include <shellapi.h>
#include <string>
#include <thread>
#include <vector>

namespace {

constexpr wchar_t kClassName[] = L"SaypickSettings";
// 工作线程取回 Ollama 模型列表：lParam = std::vector<std::wstring>*（接收方释放）
constexpr UINT kMsgOllamaModels = WM_APP + 100;

enum CtrlId : int {
    kTab = 1000,
    // General
    kEnable, kLogin, kVersionLabel, kCheckUpdate,
    // Backend
    kBackendOllama, kBackendOpenAI,
    kOllamaModelLabel, kOllamaModel, kOllamaRefresh, kOllamaHint,
    kOaiProviderLabel, kOaiProvider,
    kOaiUrlLabel, kOaiUrl, kOaiKeyLabel, kOaiKey, kOaiModelLabel, kOaiModel, kOaiHint,
    // Language
    kNativeLabel, kNative, kForeignLabel, kForeign,
    kReadDirLabel, kReadDir, kRewriteDirLabel, kRewriteDir, kLangWarn,
    // Shortcuts
    kHkReadLabel, kHkRead, kHkRewriteLabel, kHkRewrite, kHkNote,
    // Behavior
    kTriggerLabel, kTrigger, kPreview,
    kReadStyleLabel, kReadStyle, kRewriteStyleLabel, kRewriteStyle,
    // Skip apps
    kSkipEdit, kSkipAdd, kSkipList, kSkipRemove, kSkipHint,
    // About
    kAboutTitle, kAboutDesc, kAboutLinks,
};

struct State {
    HWND hwnd = nullptr;
    HWND appWindow = nullptr;
    HFONT font = nullptr, fontBold = nullptr;
    HIMAGELIST tabImages = nullptr;
    UINT dpi = 96;
    std::vector<std::vector<HWND>> pages;  // 每个 tab 页的控件
    bool loading = false;                  // 初始化填充时不触发保存
};

State g;

int px(int v) { return MulDiv(v, (int)g.dpi, 96); }

HWND ctrl(int id) { return GetDlgItem(g.hwnd, id); }

HIMAGELIST createTabImages() {
    const int size = px(16);
    HIMAGELIST images = ImageList_Create(size, size, ILC_COLOR24 | ILC_MASK, 7, 0);
    HDC dc = CreateCompatibleDC(nullptr);
    BITMAPINFO info{};
    info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    info.bmiHeader.biWidth = size;
    info.bmiHeader.biHeight = -size;
    info.bmiHeader.biPlanes = 1;
    info.bmiHeader.biBitCount = 32;
    info.bmiHeader.biCompression = BI_RGB;
    DWORD* pixels = nullptr;
    HBITMAP bitmap = CreateDIBSection(dc, &info, DIB_RGB_COLORS,
                                      reinterpret_cast<void**>(&pixels), nullptr, 0);
    HGDIOBJ oldBitmap = SelectObject(dc, bitmap);
    HBRUSH maskBrush = CreateSolidBrush(RGB(255, 0, 255));
    HPEN pen = CreatePen(PS_SOLID, std::max(1, px(1)), GetSysColor(COLOR_WINDOWTEXT));
    HGDIOBJ oldPen = SelectObject(dc, pen);
    HGDIOBJ oldBrush = SelectObject(dc, GetStockObject(NULL_BRUSH));
    auto p = [](int value) { return px(value); };
    for (int icon = 0; icon < 7; ++icon) {
        RECT rc{0, 0, size, size};
        FillRect(dc, &rc, maskBrush);
        switch (icon) {
        case 0: // General: gear
            Ellipse(dc, p(4), p(4), p(12), p(12));
            Ellipse(dc, p(7), p(7), p(9), p(9));
            MoveToEx(dc, p(8), p(1), nullptr); LineTo(dc, p(8), p(4));
            MoveToEx(dc, p(8), p(12), nullptr); LineTo(dc, p(8), p(15));
            MoveToEx(dc, p(1), p(8), nullptr); LineTo(dc, p(4), p(8));
            MoveToEx(dc, p(12), p(8), nullptr); LineTo(dc, p(15), p(8));
            break;
        case 1: // Backend: server stack
            Rectangle(dc, p(2), p(2), p(14), p(7));
            Rectangle(dc, p(2), p(9), p(14), p(14));
            Ellipse(dc, p(4), p(4), p(6), p(6));
            Ellipse(dc, p(4), p(11), p(6), p(13));
            break;
        case 2: // Language: globe
            Ellipse(dc, p(2), p(2), p(14), p(14));
            MoveToEx(dc, p(2), p(8), nullptr); LineTo(dc, p(14), p(8));
            Ellipse(dc, p(5), p(2), p(11), p(14));
            break;
        case 3: // Shortcuts: keyboard
            Rectangle(dc, p(1), p(3), p(15), p(13));
            for (int x = 4; x <= 12; x += 4) {
                MoveToEx(dc, p(x), p(5), nullptr); LineTo(dc, p(x + 1), p(5));
                MoveToEx(dc, p(x), p(8), nullptr); LineTo(dc, p(x + 1), p(8));
            }
            MoveToEx(dc, p(4), p(11), nullptr); LineTo(dc, p(12), p(11));
            break;
        case 4: // Behavior: sliders
            MoveToEx(dc, p(2), p(4), nullptr); LineTo(dc, p(14), p(4));
            MoveToEx(dc, p(2), p(8), nullptr); LineTo(dc, p(14), p(8));
            MoveToEx(dc, p(2), p(12), nullptr); LineTo(dc, p(14), p(12));
            Ellipse(dc, p(5), p(2), p(8), p(6));
            Ellipse(dc, p(10), p(6), p(13), p(10));
            Ellipse(dc, p(3), p(10), p(6), p(14));
            break;
        case 5: // Skip apps: stacked windows
            Rectangle(dc, p(2), p(4), p(12), p(13));
            MoveToEx(dc, p(5), p(2), nullptr); LineTo(dc, p(14), p(2));
            LineTo(dc, p(14), p(11));
            break;
        case 6: // About: info
            Ellipse(dc, p(2), p(2), p(14), p(14));
            Ellipse(dc, p(7), p(4), p(9), p(6));
            MoveToEx(dc, p(8), p(7), nullptr); LineTo(dc, p(8), p(12));
            break;
        }
        std::vector<BYTE> andMask(((size + 15) / 16) * 2 * size, 0xFF);
        std::vector<BYTE> xorMask(andMask.size(), 0x00);
        const int rowBytes = ((size + 15) / 16) * 2;
        for (int yy = 0; yy < size; ++yy) {
            for (int xx = 0; xx < size; ++xx) {
                if ((pixels[yy * size + xx] & 0x00FFFFFF) != 0x00FF00FF)
                    andMask[yy * rowBytes + xx / 8] &= static_cast<BYTE>(~(0x80 >> (xx % 8)));
            }
        }
        HICON iconHandle = CreateIcon(GetModuleHandleW(nullptr), size, size, 1, 1,
                                      andMask.data(), xorMask.data());
        ImageList_ReplaceIcon(images, -1, iconHandle);
        DestroyIcon(iconHandle);
    }
    SelectObject(dc, oldBrush);
    SelectObject(dc, oldPen);
    SelectObject(dc, oldBitmap);
    DeleteObject(pen);
    DeleteObject(maskBrush);
    DeleteObject(bitmap);
    DeleteDC(dc);
    return images;
}

void applyToApp() {
    if (g.appWindow) {
        // 直接调用（同线程）重装配热键 / 划词触发
        App::shared().applyEnabledState();
    }
}

// ---------- 控件创建辅助 ----------

HWND make(const wchar_t* cls, const wchar_t* text, DWORD style, int x, int y, int w, int h,
          int id, DWORD exStyle = 0) {
    HWND c = CreateWindowExW(exStyle, cls, text, WS_CHILD | style, px(x), px(y), px(w), px(h),
                             g.hwnd, (HMENU)(INT_PTR)id, GetModuleHandleW(nullptr), nullptr);
    SendMessageW(c, WM_SETFONT, (WPARAM)g.font, TRUE);
    return c;
}

HWND makeLabel(const wchar_t* text, int x, int y, int w, int id, bool bold = false) {
    HWND c = make(L"STATIC", text, SS_LEFT, x, y, w, 18, id);
    if (bold) SendMessageW(c, WM_SETFONT, (WPARAM)g.fontBold, TRUE);
    return c;
}

void fillLanguageCombo(HWND combo, Language selected) {
    SendMessageW(combo, CB_RESETCONTENT, 0, 0);
    for (Language l : lang::All) {
        int idx = (int)SendMessageW(combo, CB_ADDSTRING, 0, (LPARAM)lang::DisplayName(l));
        if (l == selected) SendMessageW(combo, CB_SETCURSEL, idx, 0);
    }
}

Language comboLanguage(HWND combo) {
    int idx = (int)SendMessageW(combo, CB_GETCURSEL, 0, 0);
    if (idx < 0 || idx >= (int)std::size(lang::All)) return Language::English;
    return lang::All[idx];
}

void fillDirectionCombo(HWND combo, TranslationDirection selected) {
    const Settings& s = Settings::shared();
    std::wstring native = lang::ShortName(s.nativeLanguage);
    std::wstring foreign = lang::ShortName(s.foreignLanguage);
    std::wstring items[] = {
        L"Auto · bidirectional",
        native + L" → " + foreign,
        foreign + L" → " + native,
    };
    SendMessageW(combo, CB_RESETCONTENT, 0, 0);
    for (auto& it : items) SendMessageW(combo, CB_ADDSTRING, 0, (LPARAM)it.c_str());
    SendMessageW(combo, CB_SETCURSEL, (int)selected, 0);
}

void fillStyleCombo(HWND combo, RewriteStyle selected) {
    SendMessageW(combo, CB_RESETCONTENT, 0, 0);
    const RewriteStyle all[] = {RewriteStyle::Faithful, RewriteStyle::Formal,
                                RewriteStyle::Casual, RewriteStyle::Polished};
    for (RewriteStyle st : all) {
        int idx = (int)SendMessageW(combo, CB_ADDSTRING, 0, (LPARAM)lang::StyleDisplayName(st));
        if (st == selected) SendMessageW(combo, CB_SETCURSEL, idx, 0);
    }
}

RewriteStyle comboStyle(HWND combo) {
    const RewriteStyle all[] = {RewriteStyle::Faithful, RewriteStyle::Formal,
                                RewriteStyle::Casual, RewriteStyle::Polished};
    int idx = (int)SendMessageW(combo, CB_GETCURSEL, 0, 0);
    return (idx >= 0 && idx < 4) ? all[idx] : RewriteStyle::Faithful;
}

std::wstring editText(HWND edit) {
    int n = GetWindowTextLengthW(edit);
    std::wstring s(n, 0);
    if (n) GetWindowTextW(edit, s.data(), n + 1);
    return s;
}

// HOTKEY 控件 ⇄ RegisterHotKey 修饰键转换
WORD hotkeyToControl(const Hotkey& hk) {
    BYTE flags = 0;
    if (hk.modifiers & MOD_SHIFT) flags |= HOTKEYF_SHIFT;
    if (hk.modifiers & MOD_CONTROL) flags |= HOTKEYF_CONTROL;
    if (hk.modifiers & MOD_ALT) flags |= HOTKEYF_ALT;
    return MAKEWORD(hk.vk, flags);
}

Hotkey hotkeyFromControl(WORD w) {
    Hotkey hk;
    hk.vk = LOBYTE(w);
    BYTE flags = HIBYTE(w);
    hk.modifiers = 0;
    if (flags & HOTKEYF_SHIFT) hk.modifiers |= MOD_SHIFT;
    if (flags & HOTKEYF_CONTROL) hk.modifiers |= MOD_CONTROL;
    if (flags & HOTKEYF_ALT) hk.modifiers |= MOD_ALT;
    return hk;
}

// ---------- 页构建 ----------

void updateBackendEnabled() {
    const Settings& s = Settings::shared();
    bool ollama = s.backend == TranslationBackend::Ollama;
    EnableWindow(ctrl(kOllamaModel), ollama);
    EnableWindow(ctrl(kOllamaRefresh), ollama);
    EnableWindow(ctrl(kOaiProvider), !ollama);
    EnableWindow(ctrl(kOaiUrl), !ollama);
    EnableWindow(ctrl(kOaiKey), !ollama);
    EnableWindow(ctrl(kOaiModel), !ollama);
}

int cloudProviderIndex(const std::string& baseUrl) {
    if (baseUrl.find("api.openai.com") != std::string::npos) return 0;
    if (baseUrl.find("openrouter.ai") != std::string::npos) return 1;
    if (baseUrl.find("api.deepseek.com") != std::string::npos) return 2;
    return 3;
}

void applyCloudProviderPreset(int index) {
    Settings& s = Settings::shared();
    switch (index) {
    case 0:
        s.openAIBaseURL = "https://api.openai.com/v1";
        s.openAIModel = "gpt-5-mini";
        break;
    case 1:
        s.openAIBaseURL = "https://openrouter.ai/api/v1";
        s.openAIModel = "openai/gpt-5-mini";
        break;
    case 2:
        s.openAIBaseURL = "https://api.deepseek.com";
        s.openAIModel = "deepseek-v4-flash";
        break;
    default:
        return;
    }
    SetWindowTextW(ctrl(kOaiUrl), util::Widen(s.openAIBaseURL).c_str());
    SetWindowTextW(ctrl(kOaiModel), util::Widen(s.openAIModel).c_str());
}

/// 后台拉取已装模型列表，回主线程填充下拉框（Settings 快照在主线程拍好）
void fetchOllamaModelsAsync() {
    ollamamodels::FetchInstalledAsync(g.hwnd, kMsgOllamaModels);
}

void updateLangWarn() {
    const Settings& s = Settings::shared();
    SetWindowTextW(ctrl(kLangWarn),
                   s.nativeLanguage == s.foreignLanguage
                       ? L"⚠ Native and foreign are the same language — translation won't do anything useful."
                       : L"Saypick translates between your native and foreign language. Auto direction detects the text and translates the other way.");
}

void buildPages() {
    const Settings& s = Settings::shared();
    g.pages.assign(7, {});
    const int x = 24, w = 620;
    int y;

    // --- 0 General ---
    y = 56;
    g.pages[0] = {
        make(L"BUTTON", L"Enable Saypick", WS_TABSTOP | BS_AUTOCHECKBOX, x, y, w, 22, kEnable),
        make(L"BUTTON", L"Launch at login", WS_TABSTOP | BS_AUTOCHECKBOX, x, y + 32, w, 22, kLogin),
        makeLabel(L"Version " SAYPICK_VERSION_STRING, x, y + 76, 200, kVersionLabel),
        make(L"BUTTON", L"Check for updates", WS_TABSTOP | BS_PUSHBUTTON, x, y + 102, 150, 26, kCheckUpdate),
    };
    CheckDlgButton(g.hwnd, kEnable, s.enabled ? BST_CHECKED : BST_UNCHECKED);
    CheckDlgButton(g.hwnd, kLogin, launchatlogin::IsEnabled() ? BST_CHECKED : BST_UNCHECKED);

    // --- 1 Backend ---
    y = 56;
    g.pages[1] = {
        make(L"BUTTON", L"Local (Ollama) — private, offline", WS_TABSTOP | WS_GROUP | BS_AUTORADIOBUTTON,
             x, y, w, 22, kBackendOllama),
        makeLabel(L"Model:", x + 20, y + 30, 60, kOllamaModelLabel),
        // 可编辑下拉框：列出已装模型，也允许手输
        make(L"COMBOBOX", L"", WS_TABSTOP | CBS_DROPDOWN | WS_VSCROLL, x + 85, y + 28, 220, 240, kOllamaModel),
        make(L"BUTTON", L"Refresh", WS_TABSTOP | BS_PUSHBUTTON, x + 315, y + 27, 70, 26, kOllamaRefresh),
        makeLabel(L"Ollama at http://127.0.0.1:11434 — run `ollama serve` and pull a model first.",
                  x + 20, y + 58, w - 20, kOllamaHint),
        make(L"BUTTON", L"Cloud API — OpenAI-compatible streaming", WS_TABSTOP | BS_AUTORADIOBUTTON,
             x, y + 96, w, 22, kBackendOpenAI),
        makeLabel(L"Provider:", x + 20, y + 126, 72, kOaiProviderLabel),
        make(L"COMBOBOX", L"", WS_TABSTOP | CBS_DROPDOWNLIST, x + 100, y + 123, 210, 180, kOaiProvider),
        makeLabel(L"Base URL:", x + 20, y + 158, 72, kOaiUrlLabel),
        make(L"EDIT", L"", WS_TABSTOP | WS_BORDER | ES_AUTOHSCROLL, x + 100, y + 155, 390, 24, kOaiUrl),
        makeLabel(L"API key:", x + 20, y + 190, 72, kOaiKeyLabel),
        make(L"EDIT", L"", WS_TABSTOP | WS_BORDER | ES_AUTOHSCROLL | ES_PASSWORD, x + 100, y + 187, 390, 24, kOaiKey),
        makeLabel(L"Model:", x + 20, y + 222, 72, kOaiModelLabel),
        make(L"EDIT", L"", WS_TABSTOP | WS_BORDER | ES_AUTOHSCROLL, x + 100, y + 219, 260, 24, kOaiModel),
        makeLabel(L"API key is stored securely in Windows Credential Manager.",
                  x + 20, y + 252, w - 20, kOaiHint),
    };
    CheckDlgButton(g.hwnd, s.backend == TranslationBackend::Ollama ? kBackendOllama : kBackendOpenAI, BST_CHECKED);
    SetWindowTextW(ctrl(kOllamaModel), util::Widen(s.ollamaModel).c_str());
    SetWindowTextW(ctrl(kOaiUrl), util::Widen(s.openAIBaseURL).c_str());
    SetWindowTextW(ctrl(kOaiKey), util::Widen(s.openAIKey).c_str());
    SetWindowTextW(ctrl(kOaiModel), util::Widen(s.openAIModel).c_str());
    {
        HWND provider = ctrl(kOaiProvider);
        const wchar_t* providers[] = {L"OpenAI", L"OpenRouter", L"DeepSeek", L"Custom endpoint"};
        for (auto* name : providers) SendMessageW(provider, CB_ADDSTRING, 0, (LPARAM)name);
        SendMessageW(provider, CB_SETCURSEL, cloudProviderIndex(s.openAIBaseURL), 0);
    }
    updateBackendEnabled();

    // --- 2 Language ---
    y = 56;
    g.pages[2] = {
        makeLabel(L"Native language:", x, y + 3, 120, kNativeLabel),
        make(L"COMBOBOX", L"", WS_TABSTOP | CBS_DROPDOWNLIST | WS_VSCROLL, x + 140, y, 240, 300, kNative),
        makeLabel(L"Foreign language:", x, y + 37, 120, kForeignLabel),
        make(L"COMBOBOX", L"", WS_TABSTOP | CBS_DROPDOWNLIST | WS_VSCROLL, x + 140, y + 34, 240, 300, kForeign),
        makeLabel(L"Read direction:", x, y + 85, 120, kReadDirLabel),
        make(L"COMBOBOX", L"", WS_TABSTOP | CBS_DROPDOWNLIST, x + 140, y + 82, 240, 200, kReadDir),
        makeLabel(L"Rewrite direction:", x, y + 119, 120, kRewriteDirLabel),
        make(L"COMBOBOX", L"", WS_TABSTOP | CBS_DROPDOWNLIST, x + 140, y + 116, 240, 200, kRewriteDir),
        makeLabel(L"", x, y + 156, w, kLangWarn),
    };
    fillLanguageCombo(ctrl(kNative), s.nativeLanguage);
    fillLanguageCombo(ctrl(kForeign), s.foreignLanguage);
    fillDirectionCombo(ctrl(kReadDir), s.readDirection);
    fillDirectionCombo(ctrl(kRewriteDir), s.rewriteDirection);
    updateLangWarn();
    // 警告区两行高
    SetWindowPos(ctrl(kLangWarn), nullptr, px(x), px(y + 156), px(w), px(40), SWP_NOZORDER);

    // --- 3 Shortcuts ---
    y = 56;
    g.pages[3] = {
        makeLabel(L"Translate selection (read):", x, y + 4, 180, kHkReadLabel),
        make(HOTKEY_CLASSW, L"", WS_TABSTOP, x + 195, y, 180, 24, kHkRead),
        makeLabel(L"Rewrite && replace (write):", x, y + 38, 180, kHkRewriteLabel),
        make(HOTKEY_CLASSW, L"", WS_TABSTOP, x + 195, y + 34, 180, 24, kHkRewrite),
        makeLabel(L"Click a field and press the new key combo. Applied immediately.",
                  x, y + 76, w, kHkNote),
    };
    SendMessageW(ctrl(kHkRead), HKM_SETHOTKEY, hotkeyToControl(s.readShortcut), 0);
    SendMessageW(ctrl(kHkRewrite), HKM_SETHOTKEY, hotkeyToControl(s.rewriteShortcut), 0);

    // --- 4 Behavior ---
    y = 56;
    g.pages[4] = {
        makeLabel(L"On text selection:", x, y + 3, 130, kTriggerLabel),
        make(L"COMBOBOX", L"", WS_TABSTOP | CBS_DROPDOWNLIST, x + 150, y, 230, 200, kTrigger),
        make(L"BUTTON", L"Preview before replacing (rewrite)", WS_TABSTOP | BS_AUTOCHECKBOX,
             x, y + 44, w, 22, kPreview),
        makeLabel(L"Read style:", x, y + 87, 130, kReadStyleLabel),
        make(L"COMBOBOX", L"", WS_TABSTOP | CBS_DROPDOWNLIST, x + 150, y + 84, 230, 200, kReadStyle),
        makeLabel(L"Rewrite style:", x, y + 121, 130, kRewriteStyleLabel),
        make(L"COMBOBOX", L"", WS_TABSTOP | CBS_DROPDOWNLIST, x + 150, y + 118, 230, 200, kRewriteStyle),
    };
    {
        HWND trig = ctrl(kTrigger);
        const wchar_t* items[] = {L"Off (shortcut only)", L"Show floating icon", L"Auto-translate"};
        for (auto* it : items) SendMessageW(trig, CB_ADDSTRING, 0, (LPARAM)it);
        SendMessageW(trig, CB_SETCURSEL, (int)s.selectionTrigger, 0);
    }
    CheckDlgButton(g.hwnd, kPreview, s.rewritePreview ? BST_CHECKED : BST_UNCHECKED);
    fillStyleCombo(ctrl(kReadStyle), s.readStyle);
    fillStyleCombo(ctrl(kRewriteStyle), s.rewriteStyle);

    // --- 5 Skip Apps ---
    y = 56;
    g.pages[5] = {
        make(L"EDIT", L"", WS_TABSTOP | WS_BORDER | ES_AUTOHSCROLL, x, y, 280, 24, kSkipEdit),
        make(L"BUTTON", L"Add", WS_TABSTOP | BS_PUSHBUTTON, x + 290, y - 1, 70, 26, kSkipAdd),
        make(L"LISTBOX", L"", WS_TABSTOP | WS_BORDER | WS_VSCROLL | LBS_NOTIFY, x, y + 34, 360, 240, kSkipList),
        make(L"BUTTON", L"Remove", WS_TABSTOP | BS_PUSHBUTTON, x + 370, y + 34, 80, 26, kSkipRemove),
        makeLabel(L"Saypick stays inactive in these apps (exe name, e.g. notepad or code.exe).",
                  x, y + 284, w, kSkipHint),
    };
    for (auto& app : s.skipApps)
        SendMessageW(ctrl(kSkipList), LB_ADDSTRING, 0, (LPARAM)app.c_str());

    // --- 6 About ---
    y = 56;
    g.pages[6] = {
        makeLabel(L"Saypick " SAYPICK_VERSION_STRING, x, y, 300, kAboutTitle, true),
        makeLabel(L"System-wide AI translation && inline rewrite for Windows.\n"
                  L"Private local models or secure OpenAI-compatible cloud APIs.",
                  x, y + 28, w, kAboutDesc),
        make(L"SysLink",
             L"<a href=\"https://github.com/everettjf/Saypick\">GitHub</a>   ·   "
             L"<a href=\"https://everettjf.github.io/Saypick/\">Website</a>   ·   "
             L"<a href=\"https://discord.com/invite/eGzEaP6TzR\">Discord</a>",
             WS_TABSTOP, x, y + 84, w, 22, kAboutLinks),
    };
    // 描述区两行高
    SetWindowPos(ctrl(kAboutDesc), nullptr, px(x), px(y + 28), px(w), px(40), SWP_NOZORDER);
}

void showPage(int index) {
    for (int p = 0; p < (int)g.pages.size(); ++p)
        for (HWND c : g.pages[p])
            ShowWindow(c, p == index ? SW_SHOW : SW_HIDE);
}

// ---------- 变更处理 ----------

void onCommand(int id, int code) {
    if (g.loading) return;
    Settings& s = Settings::shared();
    bool save = true, reapply = false;

    switch (id) {
    case kEnable:
        s.enabled = IsDlgButtonChecked(g.hwnd, kEnable) == BST_CHECKED;
        reapply = true;
        break;
    case kLogin:
        launchatlogin::SetEnabled(IsDlgButtonChecked(g.hwnd, kLogin) == BST_CHECKED);
        save = false;
        break;
    case kCheckUpdate:
        updatechecker::CheckNow(g.appWindow, WM_APP_UPDATE);
        updatechecker::OpenReleasesPage();
        save = false;
        break;

    case kBackendOllama:
    case kBackendOpenAI:
        s.backend = id == kBackendOllama ? TranslationBackend::Ollama : TranslationBackend::OpenAI;
        updateBackendEnabled();
        break;
    case kOllamaModel:
        if (code == CBN_SELCHANGE) {
            int sel = (int)SendMessageW(ctrl(kOllamaModel), CB_GETCURSEL, 0, 0);
            if (sel < 0) return;
            int len = (int)SendMessageW(ctrl(kOllamaModel), CB_GETLBTEXTLEN, sel, 0);
            std::wstring m(len, 0);
            SendMessageW(ctrl(kOllamaModel), CB_GETLBTEXT, sel, (LPARAM)m.data());
            s.ollamaModel = util::Narrow(m);
        } else if (code == CBN_EDITCHANGE) {
            s.ollamaModel = util::Narrow(editText(ctrl(kOllamaModel)));
        } else {
            return;
        }
        break;
    case kOllamaRefresh:
        fetchOllamaModelsAsync();
        save = false;
        break;
    case kOaiProvider:
        if (code != CBN_SELCHANGE) return;
        applyCloudProviderPreset((int)SendMessageW(ctrl(kOaiProvider), CB_GETCURSEL, 0, 0));
        break;
    case kOaiUrl:
        if (code != EN_CHANGE) return;
        s.openAIBaseURL = util::Narrow(editText(ctrl(kOaiUrl)));
        break;
    case kOaiKey:
        if (code != EN_KILLFOCUS) return;
        s.openAIKey = util::Narrow(editText(ctrl(kOaiKey)));
        break;
    case kOaiModel:
        if (code != EN_CHANGE) return;
        s.openAIModel = util::Narrow(editText(ctrl(kOaiModel)));
        break;

    case kNative:
        if (code != CBN_SELCHANGE) return;
        s.nativeLanguage = comboLanguage(ctrl(kNative));
        fillDirectionCombo(ctrl(kReadDir), s.readDirection);
        fillDirectionCombo(ctrl(kRewriteDir), s.rewriteDirection);
        updateLangWarn();
        break;
    case kForeign:
        if (code != CBN_SELCHANGE) return;
        s.foreignLanguage = comboLanguage(ctrl(kForeign));
        fillDirectionCombo(ctrl(kReadDir), s.readDirection);
        fillDirectionCombo(ctrl(kRewriteDir), s.rewriteDirection);
        updateLangWarn();
        break;
    case kReadDir:
        if (code != CBN_SELCHANGE) return;
        s.readDirection = (TranslationDirection)SendMessageW(ctrl(kReadDir), CB_GETCURSEL, 0, 0);
        break;
    case kRewriteDir:
        if (code != CBN_SELCHANGE) return;
        s.rewriteDirection = (TranslationDirection)SendMessageW(ctrl(kRewriteDir), CB_GETCURSEL, 0, 0);
        break;

    case kHkRead:
        if (code != EN_CHANGE) return;
        {
            Hotkey hk = hotkeyFromControl((WORD)SendMessageW(ctrl(kHkRead), HKM_GETHOTKEY, 0, 0));
            if (hk.vk == 0) return;  // 未设置完
            s.readShortcut = hk;
            reapply = true;
        }
        break;
    case kHkRewrite:
        if (code != EN_CHANGE) return;
        {
            Hotkey hk = hotkeyFromControl((WORD)SendMessageW(ctrl(kHkRewrite), HKM_GETHOTKEY, 0, 0));
            if (hk.vk == 0) return;
            s.rewriteShortcut = hk;
            reapply = true;
        }
        break;

    case kTrigger:
        if (code != CBN_SELCHANGE) return;
        s.selectionTrigger = (SelectionTrigger)SendMessageW(ctrl(kTrigger), CB_GETCURSEL, 0, 0);
        reapply = true;
        break;
    case kPreview:
        s.rewritePreview = IsDlgButtonChecked(g.hwnd, kPreview) == BST_CHECKED;
        break;
    case kReadStyle:
        if (code != CBN_SELCHANGE) return;
        s.readStyle = comboStyle(ctrl(kReadStyle));
        break;
    case kRewriteStyle:
        if (code != CBN_SELCHANGE) return;
        s.rewriteStyle = comboStyle(ctrl(kRewriteStyle));
        break;

    case kSkipAdd: {
        std::wstring app = util::Trim(editText(ctrl(kSkipEdit)));
        if (app.empty()) { save = false; break; }
        for (auto& e : s.skipApps)
            if (util::ToLower(e) == util::ToLower(app)) { save = false; break; }
        if (!save) break;
        s.skipApps.push_back(app);
        SendMessageW(ctrl(kSkipList), LB_ADDSTRING, 0, (LPARAM)app.c_str());
        SetWindowTextW(ctrl(kSkipEdit), L"");
        break;
    }
    case kSkipRemove: {
        int sel = (int)SendMessageW(ctrl(kSkipList), LB_GETCURSEL, 0, 0);
        if (sel < 0 || sel >= (int)s.skipApps.size()) { save = false; break; }
        s.skipApps.erase(s.skipApps.begin() + sel);
        SendMessageW(ctrl(kSkipList), LB_DELETESTRING, sel, 0);
        break;
    }

    default:
        return;
    }

    if (save) s.save();
    if (reapply) applyToApp();
}

LRESULT CALLBACK wndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
    case WM_COMMAND:
        onCommand(LOWORD(wp), HIWORD(wp));
        return 0;
    case kMsgOllamaModels: {
        auto* models = (std::vector<std::wstring>*)lp;
        ollamamodels::ApplyResolvedModels(*models);
        HWND combo = ctrl(kOllamaModel);
        if (combo) {
            std::wstring current = util::Widen(Settings::shared().ollamaModel);
            SendMessageW(combo, CB_RESETCONTENT, 0, 0);
            for (auto& m : *models)
                SendMessageW(combo, CB_ADDSTRING, 0, (LPARAM)m.c_str());
            SetWindowTextW(combo, current.c_str());
        }
        ollamamodels::PreloadAsync();
        delete models;
        return 0;
    }
    case WM_NOTIFY: {
        auto* hdr = (NMHDR*)lp;
        if (hdr->idFrom == kTab && hdr->code == TCN_SELCHANGE) {
            showPage(TabCtrl_GetCurSel(hdr->hwndFrom));
            return 0;
        }
        if (hdr->idFrom == kAboutLinks && (hdr->code == NM_CLICK || hdr->code == NM_RETURN)) {
            auto* link = (NMLINK*)lp;
            ShellExecuteW(nullptr, L"open", link->item.szUrl, nullptr, nullptr, SW_SHOWNORMAL);
            return 0;
        }
        break;
    }
    case WM_CTLCOLORSTATIC:
        SetBkMode((HDC)wp, TRANSPARENT);
        return (LRESULT)GetSysColorBrush(COLOR_WINDOW);
    case WM_ERASEBKGND: {
        RECT rc{};
        GetClientRect(hwnd, &rc);
        FillRect((HDC)wp, &rc, GetSysColorBrush(COLOR_WINDOW));
        return 1;
    }
    case WM_CLOSE:
        DestroyWindow(hwnd);
        return 0;
    case WM_DESTROY:
        if (g.font) { DeleteObject(g.font); g.font = nullptr; }
        if (g.fontBold) { DeleteObject(g.fontBold); g.fontBold = nullptr; }
        if (g.tabImages) { ImageList_Destroy(g.tabImages); g.tabImages = nullptr; }
        g.hwnd = nullptr;
        g.pages.clear();
        return 0;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

} // namespace

namespace SettingsWindow {

void open(HWND appWindow) {
    if (g.hwnd) {
        ShowWindow(g.hwnd, SW_SHOWNORMAL);
        SetForegroundWindow(g.hwnd);
        return;
    }
    g.appWindow = appWindow;

    static bool registered = [] {
        INITCOMMONCONTROLSEX icc{sizeof(icc), ICC_TAB_CLASSES | ICC_HOTKEY_CLASS | ICC_LINK_CLASS |
                                                  ICC_STANDARD_CLASSES};
        InitCommonControlsEx(&icc);
        WNDCLASSW wc{};
        wc.lpfnWndProc = wndProc;
        wc.hInstance = GetModuleHandleW(nullptr);
        wc.lpszClassName = kClassName;
        wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
        wc.hIcon = LoadIconW(wc.hInstance, MAKEINTRESOURCEW(IDI_APPICON));
        wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
        RegisterClassW(&wc);
        return true;
    }();
    (void)registered;

    g.dpi = GetDpiForSystem();
    int w = px(680), h = px(500);
    RECT wr{0, 0, w, h};
    AdjustWindowRect(&wr, WS_OVERLAPPEDWINDOW & ~(WS_MAXIMIZEBOX | WS_THICKFRAME), FALSE);

    g.hwnd = CreateWindowExW(0, kClassName, L"Saypick Settings",
                             (WS_OVERLAPPEDWINDOW & ~(WS_MAXIMIZEBOX | WS_THICKFRAME)) | WS_VISIBLE,
                             CW_USEDEFAULT, CW_USEDEFAULT,
                             wr.right - wr.left, wr.bottom - wr.top,
                             nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
    if (!g.hwnd) return;

    HICON smallIcon = (HICON)LoadImageW(GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APPICON),
                                        IMAGE_ICON, px(16), px(16), LR_DEFAULTCOLOR | LR_SHARED);
    SendMessageW(g.hwnd, WM_SETICON, ICON_BIG,
                 (LPARAM)LoadIconW(GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APPICON)));
    SendMessageW(g.hwnd, WM_SETICON, ICON_SMALL, (LPARAM)smallIcon);

    // 字体
    NONCLIENTMETRICSW ncm{sizeof(ncm)};
    SystemParametersInfoW(SPI_GETNONCLIENTMETRICS, sizeof(ncm), &ncm, 0);
    g.font = CreateFontIndirectW(&ncm.lfMessageFont);
    LOGFONTW bold = ncm.lfMessageFont;
    bold.lfWeight = FW_SEMIBOLD;
    bold.lfHeight = MulDiv(bold.lfHeight, 5, 4);
    g.fontBold = CreateFontIndirectW(&bold);

    g.loading = true;

    // Tab 控件
    HWND tab = CreateWindowExW(0, WC_TABCONTROLW, L"", WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS,
                               0, 0, w, h, g.hwnd, (HMENU)kTab, GetModuleHandleW(nullptr), nullptr);
    SendMessageW(tab, WM_SETFONT, (WPARAM)g.font, TRUE);
    g.tabImages = createTabImages();
    TabCtrl_SetImageList(tab, g.tabImages);
    TabCtrl_SetPadding(tab, px(8), px(5));
    const wchar_t* names[] = {L"General", L"Backend", L"Language", L"Shortcuts",
                              L"Behavior", L"Skip Apps", L"About"};
    for (int i = 0; i < 7; ++i) {
        TCITEMW item{TCIF_TEXT | TCIF_IMAGE};
        item.pszText = (LPWSTR)names[i];
        item.iImage = i;
        TabCtrl_InsertItem(tab, i, &item);
    }

    buildPages();
    showPage(0);
    g.loading = false;

    // 异步填充 Ollama 模型下拉框
    fetchOllamaModelsAsync();

    SetForegroundWindow(g.hwnd);
}

} // namespace SettingsWindow
