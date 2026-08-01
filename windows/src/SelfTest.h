//
//  SelfTest.h — `TypeTide.exe --selftest` 的内建自检（JSON / 检测 / 设置 / 提示词等）。
//  `--selftest-translate` 额外用当前 settings.json 的后端跑一次真实翻译。
//
#pragma once

/// 返回失败用例数（0 = 全部通过）。输出写 stdout。
int RunSelfTests(bool includeLiveTranslate);
