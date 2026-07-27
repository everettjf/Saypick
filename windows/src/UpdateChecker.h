//
//  UpdateChecker.h — GitHub Releases 版本检测（对应 macOS 的 UpdateChecker）。
//
#pragma once
#include <windows.h>
#include <string>

namespace updatechecker {

/// 每天最多检查一次；有新版本时向 notifyWindow 投递 notifyMessage
/// （wParam=1；释放页 URL 存内部状态）。工作线程执行。
void CheckIfDue(HWND notifyWindow, UINT notifyMessage);

/// 立即检查（忽略每日限制）
void CheckNow(HWND notifyWindow, UINT notifyMessage);

/// 用户主动检查：无论结果如何都投递消息。
/// wParam: 0=已是最新版，1=有新版本，2=检查失败。
void CheckNowInteractive(HWND notifyWindow, UINT notifyMessage);

/// 最新版本的发布页（无则返回 releases 首页）
std::wstring ReleasesURL();

/// 打开发布页
void OpenReleasesPage();

} // namespace updatechecker
