#include "Hooks.h"
#include <map>

namespace hooks {

namespace {

std::map<int, MouseFn> g_mouse;
std::map<int, KeyFn> g_key;
int g_nextId = 1;
HHOOK g_mouseHook = nullptr;
HHOOK g_keyHook = nullptr;

LRESULT CALLBACK mouseProc(int code, WPARAM wParam, LPARAM lParam) {
    if (code == HC_ACTION) {
        auto* info = (MSLLHOOKSTRUCT*)lParam;
        // 快照订阅者，允许回调中增删
        auto subs = g_mouse;
        for (auto& [id, fn] : subs) fn(wParam, info->pt);
    }
    return CallNextHookEx(nullptr, code, wParam, lParam);
}

LRESULT CALLBACK keyProc(int code, WPARAM wParam, LPARAM lParam) {
    if (code == HC_ACTION && (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN)) {
        auto* info = (KBDLLHOOKSTRUCT*)lParam;
        auto subs = g_key;
        for (auto& [id, fn] : subs)
            if (fn(info->vkCode)) return 1;  // 吞掉
    }
    return CallNextHookEx(nullptr, code, wParam, lParam);
}

void syncHooks() {
    if (!g_mouse.empty() && !g_mouseHook)
        g_mouseHook = SetWindowsHookExW(WH_MOUSE_LL, mouseProc, GetModuleHandleW(nullptr), 0);
    if (g_mouse.empty() && g_mouseHook) {
        UnhookWindowsHookEx(g_mouseHook);
        g_mouseHook = nullptr;
    }
    if (!g_key.empty() && !g_keyHook)
        g_keyHook = SetWindowsHookExW(WH_KEYBOARD_LL, keyProc, GetModuleHandleW(nullptr), 0);
    if (g_key.empty() && g_keyHook) {
        UnhookWindowsHookEx(g_keyHook);
        g_keyHook = nullptr;
    }
}

} // namespace

int AddMouse(MouseFn fn) {
    int id = g_nextId++;
    g_mouse[id] = std::move(fn);
    syncHooks();
    return id;
}

void RemoveMouse(int id) {
    g_mouse.erase(id);
    syncHooks();
}

int AddKey(KeyFn fn) {
    int id = g_nextId++;
    g_key[id] = std::move(fn);
    syncHooks();
    return id;
}

void RemoveKey(int id) {
    g_key.erase(id);
    syncHooks();
}

} // namespace hooks
