#include "LaunchAtLogin.h"
#include <windows.h>
#include <string>

namespace launchatlogin {

namespace {
constexpr wchar_t kRunKey[] = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kValueName[] = L"Saypick";
} // namespace

bool IsEnabled() {
    wchar_t buf[MAX_PATH * 2]{};
    DWORD size = sizeof(buf);
    LSTATUS st = RegGetValueW(HKEY_CURRENT_USER, kRunKey, kValueName,
                              RRF_RT_REG_SZ, nullptr, buf, &size);
    return st == ERROR_SUCCESS;
}

void SetEnabled(bool enabled) {
    HKEY key = nullptr;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, kRunKey, 0, KEY_SET_VALUE, &key) != ERROR_SUCCESS)
        return;
    if (enabled) {
        wchar_t exe[MAX_PATH]{};
        GetModuleFileNameW(nullptr, exe, MAX_PATH);
        std::wstring quoted = L"\"" + std::wstring(exe) + L"\"";
        RegSetValueExW(key, kValueName, 0, REG_SZ, (const BYTE*)quoted.c_str(),
                       (DWORD)((quoted.size() + 1) * sizeof(wchar_t)));
    } else {
        RegDeleteValueW(key, kValueName);
    }
    RegCloseKey(key);
}

} // namespace launchatlogin
