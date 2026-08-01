//
//  CrashDump.h — 未处理异常时写 minidump 到 %APPDATA%\TypeTide\crashes\。
//
#pragma once

namespace crashdump {

/// 安装未处理异常过滤器（进程启动时调一次）
void Install();

} // namespace crashdump
