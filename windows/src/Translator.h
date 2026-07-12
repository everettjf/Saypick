//
//  Translator.h — 翻译服务：提示词、Ollama / OpenAI 兼容后端（流式）、LRU 缓存。
//  对应 macOS 的 TranslationService + providers。
//
//  stream() 在工作线程执行，回调也在工作线程触发；
//  UI 侧（App）负责用 PostMessage 转回主线程。缓存命中时回调在调用线程同步触发。
//
#pragma once
#include "Language.h"
#include <cstdint>
#include <functional>
#include <optional>
#include <string>

struct TranslationRequest {
    std::wstring text;
    std::optional<Language> source;  // nullopt = 让模型自动判断
    Language target = Language::English;
    RewriteStyle style = RewriteStyle::Faithful;
};

namespace translator {

/// 提示词构造（与 macOS TranslationPrompt 保持一致）
std::string SystemPrompt(Language target, std::optional<Language> source, RewriteStyle style);
std::string PlainPrompt(const std::wstring& text, Language target, std::optional<Language> source, RewriteStyle style);

using DeltaFn = std::function<void(uint64_t reqId, const std::wstring& delta)>;
using DoneFn = std::function<void(uint64_t reqId, bool ok, const std::wstring& error)>;

/// 发起流式翻译，返回请求 id。命中缓存时同步回调全文 + 完成。
uint64_t Stream(const TranslationRequest& req, DeltaFn onDelta, DoneFn onDone);

/// 取消某个请求（对应流式任务尽快退出，不再回调）
void Cancel(uint64_t reqId);

/// 取消全部活跃请求（退出前调用）
void CancelAll();

/// 阻塞式完整翻译（改写直接替换用）。失败返回 nullopt 并填 error。
std::optional<std::wstring> TranslateFully(const TranslationRequest& req, std::wstring* error);

/// 测试钩子：清空缓存
void ClearCacheForTesting();

} // namespace translator
