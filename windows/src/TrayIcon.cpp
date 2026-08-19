#include "TrayIcon.h"
#include "Settings.h"
#include "resource.h"

namespace {
enum MenuId : UINT {
    kMenuUpdate = 1,
    kMenuToggle,
    kMenuReadHint,
    kMenuRewriteHint,
    kMenuSettings,
    kMenuQuit,
};

const wchar_t* actionName(ShortcutAction action) {
    switch (action) {
    case ShortcutAction::NativePopup: return L"To native · popup";
    case ShortcutAction::ForeignPopup: return L"To foreign · popup";
    case ShortcutAction::SmartReplace: return L"Smart translate · replace";
    case ShortcutAction::NativeReplace: return L"To native · replace";
    case ShortcutAction::ForeignReplace: return L"To foreign · replace";
    case ShortcutAction::SmartPopup:
    default: return L"Smart translate · popup";
    }
}
}

void TrayIcon::add(HWND owner, UINT callbackMessage) {
    nid_ = {};
    nid_.cbSize = sizeof(nid_);
    nid_.hWnd = owner;
    nid_.uID = 1;
    nid_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
    nid_.uCallbackMessage = callbackMessage;
    nid_.hIcon = (HICON)LoadImageW(GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APPICON),
                                   IMAGE_ICON, GetSystemMetrics(SM_CXSMICON),
                                   GetSystemMetrics(SM_CYSMICON), 0);
    if (!nid_.hIcon) nid_.hIcon = LoadIconW(nullptr, IDI_APPLICATION);
    wcscpy_s(nid_.szTip, L"TypeTide");
    added_ = Shell_NotifyIconW(NIM_ADD, &nid_);
    nid_.uVersion = NOTIFYICON_VERSION_4;
    Shell_NotifyIconW(NIM_SETVERSION, &nid_);
}

void TrayIcon::remove() {
    if (added_) {
        Shell_NotifyIconW(NIM_DELETE, &nid_);
        added_ = false;
    }
}

void TrayIcon::showMenu(HWND owner) {
    const Settings& s = Settings::shared();
    HMENU menu = CreatePopupMenu();

    if (updateAvailable_) {
        AppendMenuW(menu, MF_STRING, kMenuUpdate, L"⬇ New update available");
        AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    }

    AppendMenuW(menu, MF_STRING | (s.enabled ? MF_CHECKED : 0), kMenuToggle,
                s.enabled ? L"TypeTide is On" : L"TypeTide is Off");
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);

    std::wstring readHint = std::wstring(actionName(s.readShortcutAction)) + L":  " + s.readShortcut.displayString();
    std::wstring rewriteHint = std::wstring(actionName(s.rewriteShortcutAction)) + L":  " + s.rewriteShortcut.displayString();
    AppendMenuW(menu, MF_STRING | MF_GRAYED, kMenuReadHint, readHint.c_str());
    AppendMenuW(menu, MF_STRING | MF_GRAYED, kMenuRewriteHint, rewriteHint.c_str());
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);

    AppendMenuW(menu, MF_STRING, kMenuSettings, L"Settings…");
    AppendMenuW(menu, MF_STRING, kMenuQuit, L"Quit TypeTide");

    POINT pt{};
    GetCursorPos(&pt);
    SetForegroundWindow(owner);  // 官方要求：否则菜单点外部不消失
    UINT cmd = (UINT)TrackPopupMenu(menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON,
                                    pt.x, pt.y, 0, owner, nullptr);
    DestroyMenu(menu);

    switch (cmd) {
    case kMenuUpdate:
        if (onOpenReleases) onOpenReleases();
        break;
    case kMenuToggle:
        if (onToggleEnabled) onToggleEnabled();
        break;
    case kMenuSettings:
        if (onOpenSettings) onOpenSettings();
        break;
    case kMenuQuit:
        if (onQuit) onQuit();
        break;
    }
}
