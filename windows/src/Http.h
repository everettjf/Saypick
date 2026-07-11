//
//  Http.h — WinHTTP 封装：流式 POST（逐块回调）与一次性 GET。
//  在调用线程同步执行；配合工作线程 + cancel 标志使用。
//
#pragma once
#include <atomic>
#include <functional>
#include <string>

namespace http {

struct Result {
    bool ok = false;
    int status = 0;
    std::string error;   // 人读错误（网络失败 / HTTP 状态码）
    std::string body;    // 仅非流式请求填充
};

/// 流式 POST：每收到一块 body 调一次 onChunk（UTF-8 原始字节）。
/// cancel 置 true 后尽快返回。
Result PostStream(const std::wstring& url,
                  const std::string& body,
                  const std::wstring& extraHeaders,  // 形如 L"Authorization: Bearer x\r\n"，可空
                  const std::function<void(const char* data, size_t len)>& onChunk,
                  const std::atomic<bool>& cancel);

/// 一次性 GET（用于版本检查等小请求）
Result Get(const std::wstring& url, const std::wstring& extraHeaders = L"");

} // namespace http
