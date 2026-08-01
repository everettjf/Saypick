//
//  Util.h — 编码转换与零散小工具。
//
#pragma once
#include <windows.h>
#include <string>

namespace util {

inline std::wstring Widen(const std::string& s) {
    if (s.empty()) return {};
    int n = MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)s.size(), nullptr, 0);
    std::wstring w(n, 0);
    MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)s.size(), w.data(), n);
    return w;
}

inline std::string Narrow(const std::wstring& w) {
    if (w.empty()) return {};
    int n = WideCharToMultiByte(CP_UTF8, 0, w.data(), (int)w.size(), nullptr, 0, nullptr, nullptr);
    std::string s(n, 0);
    WideCharToMultiByte(CP_UTF8, 0, w.data(), (int)w.size(), s.data(), n, nullptr, nullptr);
    return s;
}

inline std::wstring Trim(const std::wstring& s) {
    const wchar_t* ws = L" \t\r\n";
    auto b = s.find_first_not_of(ws);
    if (b == std::wstring::npos) return {};
    auto e = s.find_last_not_of(ws);
    return s.substr(b, e - b + 1);
}

inline std::string Trim(const std::string& s) {
    const char* ws = " \t\r\n";
    auto b = s.find_first_not_of(ws);
    if (b == std::string::npos) return {};
    auto e = s.find_last_not_of(ws);
    return s.substr(b, e - b + 1);
}

inline std::wstring ToLower(std::wstring s) {
    CharLowerBuffW(s.data(), (DWORD)s.size());
    return s;
}

/// %APPDATA%\TypeTide 目录（不存在则创建）。
/// TYPETIDE_DATA_DIR 环境变量可覆盖（自检/测试用，避免污染真实设置）。
inline std::wstring AppDataDir() {
    wchar_t buf[MAX_PATH]{};
    DWORD n = GetEnvironmentVariableW(L"TYPETIDE_DATA_DIR", buf, MAX_PATH);
    if (n && n < MAX_PATH) {
        CreateDirectoryW(buf, nullptr);
        return buf;
    }
    n = GetEnvironmentVariableW(L"APPDATA", buf, MAX_PATH);
    std::wstring dir = (n && n < MAX_PATH) ? buf : L".";
    dir += L"\\TypeTide";
    CreateDirectoryW(dir.c_str(), nullptr);
    return dir;
}

/// 调试日志：TYPETIDE_DEBUG=1 时追加写 %data%\debug.log（含毫秒时间戳）
void Log(const char* fmt, ...);

} // namespace util
