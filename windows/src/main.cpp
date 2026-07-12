//
//  main.cpp — 入口：单实例、COM/控件初始化、消息循环。
//  `--selftest` / `--selftest-translate` 走内建自检（stdout 输出）。
//
#include <windows.h>
#include "App.h"
#include "CrashDump.h"
#include "SelfTest.h"
#include <objbase.h>
#include <shellapi.h>
#include <cstdio>
#include <string>

namespace {

int runSelfTest(bool live) {
    // stdout 已被重定向（管道/文件）就直接用；否则挂到父进程控制台
    HANDLE out = GetStdHandle(STD_OUTPUT_HANDLE);
    if (out == nullptr || out == INVALID_HANDLE_VALUE) {
        if (!AttachConsole(ATTACH_PARENT_PROCESS)) AllocConsole();
        FILE* f = nullptr;
        freopen_s(&f, "CONOUT$", "w", stdout);
        SetConsoleOutputCP(CP_UTF8);
    }
    int failures = RunSelfTests(live);
    fflush(stdout);
    return failures;
}

} // namespace

int WINAPI wWinMain(HINSTANCE inst, HINSTANCE, PWSTR cmdLine, int) {
    std::wstring args = cmdLine ? cmdLine : L"";

    crashdump::Install();
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);

    if (args.find(L"--selftest") != std::wstring::npos)
        return runSelfTest(args.find(L"--selftest-translate") != std::wstring::npos);

    // 单实例：已在运行则让它打开设置窗口
    HANDLE mutex = CreateMutexW(nullptr, TRUE, L"Local\\SaypickSingleInstance");
    if (GetLastError() == ERROR_ALREADY_EXISTS) {
        if (HWND existing = FindWindowW(kAppWindowClass, nullptr))
            PostMessageW(existing, WM_APP_OPEN_SETTINGS, 0, 0);
        return 0;
    }

    if (!App::shared().init(inst)) return 1;

    MSG msg;
    while (GetMessageW(&msg, nullptr, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    if (mutex) CloseHandle(mutex);
    CoUninitialize();
    return (int)msg.wParam;
}
