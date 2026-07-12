#include "CrashDump.h"
#include "Util.h"
#include <windows.h>
#include <dbghelp.h>
#include <algorithm>
#include <string>
#include <vector>

namespace crashdump {

namespace {

std::wstring crashesDir() {
    std::wstring dir = util::AppDataDir() + L"\\crashes";
    CreateDirectoryW(dir.c_str(), nullptr);
    return dir;
}

/// 只保留最近 5 个 dump
void pruneOld(const std::wstring& dir) {
    std::vector<std::wstring> dumps;
    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW((dir + L"\\*.dmp").c_str(), &fd);
    if (h == INVALID_HANDLE_VALUE) return;
    do {
        dumps.push_back(fd.cFileName);
    } while (FindNextFileW(h, &fd));
    FindClose(h);
    if (dumps.size() <= 5) return;
    std::sort(dumps.begin(), dumps.end());  // 文件名含时间戳，字典序即时间序
    for (size_t i = 0; i + 5 < dumps.size(); ++i)
        DeleteFileW((dir + L"\\" + dumps[i]).c_str());
}

LONG WINAPI unhandledFilter(EXCEPTION_POINTERS* info) {
    // 崩溃路径里只做最少的事
    wchar_t path[MAX_PATH * 2];
    std::wstring dir = crashesDir();
    SYSTEMTIME st;
    GetLocalTime(&st);
    swprintf_s(path, L"%s\\crash-%04d%02d%02d-%02d%02d%02d.dmp",
               dir.c_str(), st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond);

    HANDLE file = CreateFileW(path, GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS,
                              FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file != INVALID_HANDLE_VALUE) {
        MINIDUMP_EXCEPTION_INFORMATION mei{GetCurrentThreadId(), info, FALSE};
        MiniDumpWriteDump(GetCurrentProcess(), GetCurrentProcessId(), file,
                          MiniDumpNormal, info ? &mei : nullptr, nullptr, nullptr);
        CloseHandle(file);
    }
    pruneOld(dir);
    return EXCEPTION_EXECUTE_HANDLER;
}

} // namespace

void Install() {
    SetUnhandledExceptionFilter(unhandledFilter);
}

} // namespace crashdump
