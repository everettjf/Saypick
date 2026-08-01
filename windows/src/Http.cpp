#include "Http.h"
#include <windows.h>
#include <winhttp.h>
#include <vector>

namespace http {

namespace {

constexpr size_t kMaxBufferedResponse = 8 * 1024 * 1024;

struct Handle {
    HINTERNET h = nullptr;
    Handle() = default;
    explicit Handle(HINTERNET v) : h(v) {}
    ~Handle() { if (h) WinHttpCloseHandle(h); }
    Handle(const Handle&) = delete;
    Handle& operator=(const Handle&) = delete;
    explicit operator bool() const { return h != nullptr; }
};

std::string lastError(const char* stage) {
    char buf[128];
    snprintf(buf, sizeof(buf), "%s failed (code %lu)", stage, GetLastError());
    return buf;
}

Result request(const std::wstring& url,
               const wchar_t* method,
               const std::string& body,
               const std::wstring& extraHeaders,
               const std::function<void(const char*, size_t)>* onChunk,
               const std::atomic<bool>* cancel) {
    Result r;

    URL_COMPONENTS uc{};
    uc.dwStructSize = sizeof(uc);
    wchar_t host[256]{}, path[2048]{};
    uc.lpszHostName = host; uc.dwHostNameLength = 256;
    uc.lpszUrlPath = path;  uc.dwUrlPathLength = 2048;
    if (!WinHttpCrackUrl(url.c_str(), (DWORD)url.size(), 0, &uc)) {
        r.error = "Invalid URL";
        return r;
    }
    bool secure = uc.nScheme == INTERNET_SCHEME_HTTPS;

    Handle session(WinHttpOpen(L"TypeTide/1.0", WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY,
                               WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0));
    if (!session) { r.error = lastError("WinHttpOpen"); return r; }

    // 连接失败应尽快可恢复；单次 90 秒无响应后让 UI 提供 Retry。
    WinHttpSetTimeouts(session.h, 10000, 10000, 30000, 90000);

    Handle conn(WinHttpConnect(session.h, host, uc.nPort, 0));
    if (!conn) { r.error = lastError("WinHttpConnect"); return r; }

    Handle req(WinHttpOpenRequest(conn.h, method, path, nullptr,
                                  WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES,
                                  secure ? WINHTTP_FLAG_SECURE : 0));
    if (!req) { r.error = lastError("WinHttpOpenRequest"); return r; }

    std::wstring headers = L"Content-Type: application/json\r\n" + extraHeaders;
    if (!WinHttpSendRequest(req.h, headers.c_str(), (DWORD)headers.size(),
                            body.empty() ? WINHTTP_NO_REQUEST_DATA : (LPVOID)body.data(),
                            (DWORD)body.size(), (DWORD)body.size(), 0)) {
        r.error = lastError("Connection");
        return r;
    }
    if (!WinHttpReceiveResponse(req.h, nullptr)) {
        r.error = lastError("Response");
        return r;
    }

    DWORD status = 0, size = sizeof(status);
    WinHttpQueryHeaders(req.h, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                        WINHTTP_HEADER_NAME_BY_INDEX, &status, &size, WINHTTP_NO_HEADER_INDEX);
    r.status = (int)status;

    std::vector<char> buf(16 * 1024);
    for (;;) {
        if (cancel && cancel->load()) { r.error = "Cancelled"; return r; }
        DWORD avail = 0;
        if (!WinHttpQueryDataAvailable(req.h, &avail)) { r.error = lastError("Read"); return r; }
        if (avail == 0) break;
        while (avail > 0) {
            if (cancel && cancel->load()) { r.error = "Cancelled"; return r; }
            DWORD toRead = avail < buf.size() ? avail : (DWORD)buf.size();
            DWORD got = 0;
            if (!WinHttpReadData(req.h, buf.data(), toRead, &got)) { r.error = lastError("Read"); return r; }
            if (got == 0) break;
            avail -= got;
            if (onChunk && status >= 200 && status < 300) {
                (*onChunk)(buf.data(), got);
            } else {
                if (r.body.size() + got > kMaxBufferedResponse) {
                    r.error = "Response too large";
                    return r;
                }
                r.body.append(buf.data(), got);
            }
        }
    }

    if (status < 200 || status >= 300) {
        char msg[64];
        snprintf(msg, sizeof(msg), "HTTP %lu", status);
        r.error = msg;
        return r;
    }
    r.ok = true;
    return r;
}

} // namespace

Result PostStream(const std::wstring& url, const std::string& body,
                  const std::wstring& extraHeaders,
                  const std::function<void(const char*, size_t)>& onChunk,
                  const std::atomic<bool>& cancel) {
    return request(url, L"POST", body, extraHeaders, &onChunk, &cancel);
}

Result Get(const std::wstring& url, const std::wstring& extraHeaders) {
    return request(url, L"GET", {}, extraHeaders, nullptr, nullptr);
}

} // namespace http
