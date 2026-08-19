#include "OllamaModels.h"
#include "Http.h"
#include "Json.h"
#include "Settings.h"
#include "Util.h"
#include <algorithm>
#include <cstdlib>
#include <cwchar>
#include <cwctype>
#include <limits>
#include <thread>

namespace ollamamodels {

namespace {
double parameterBillions(const std::wstring& model) {
    std::wstring lower = util::ToLower(model);
    size_t b = lower.find(L'b');
    while (b != std::wstring::npos) {
        size_t start = b;
        while (start > 0 && (iswdigit(lower[start - 1]) || lower[start - 1] == L'.')) --start;
        if (start < b && (start == 0 || lower[start - 1] == L':' || lower[start - 1] == L'_' || lower[start - 1] == L'-')) {
            wchar_t* end = nullptr;
            double value = std::wcstod(lower.c_str() + start, &end);
            if (end == lower.c_str() + b && value > 0) return value;
        }
        b = lower.find(L'b', b + 1);
    }
    return -1;
}
} // namespace

std::vector<std::wstring> ListInstalled(const std::string& host, int port, std::wstring* error) {
    std::wstring url = util::Widen(host) + L":" + std::to_wstring(port) + L"/api/tags";

    http::Result r = http::Get(url);
    if (!r.ok) {
        if (error)
            *error = r.status == 0 ? L"Can't reach Ollama — is `ollama serve` running?"
                                   : util::Widen(r.error);
        return {};
    }
    bool ok = false;
    json::Value v = json::Parse(r.body, &ok);
    if (!ok) {
        if (error) *error = L"Unexpected response from Ollama";
        return {};
    }
    std::vector<std::wstring> models;
    if (const json::Array* arr = v["models"].array())
        for (auto& m : *arr)
            if (m["name"].isString()) models.push_back(util::Widen(m["name"].asString()));
    return models;
}

void FetchInstalledAsync(HWND notify, UINT message) {
    // Settings 快照在调用（主）线程拍好，工作线程只碰局部拷贝
    const Settings& s = Settings::shared();
    std::string host = s.ollamaHost;
    int port = s.ollamaPort;

    std::thread([notify, message, host, port] {
        auto* models = new std::vector<std::wstring>(ListInstalled(host, port, nullptr));
        if (!PostMessageW(notify, message, 0, (LPARAM)models)) delete models;
    }).detach();
}

void PreloadAsync() {
    const Settings& s = Settings::shared();
    if (s.backend != TranslationBackend::Ollama || s.ollamaModel.empty()) return;
    const std::string host = s.ollamaHost;
    const int port = s.ollamaPort;
    const std::string model = s.ollamaModel;

    std::thread([host, port, model] {
        json::Object body;
        body["model"] = model;
        body["prompt"] = "";
        body["stream"] = false;
        body["keep_alive"] = "10m";
        body["think"] = false;
        std::atomic<bool> cancel{false};
        const std::wstring url = util::Widen(host) + L":" + std::to_wstring(port) + L"/api/generate";
        http::Result r = http::PostStream(url, json::Value(std::move(body)).dump(), L"",
                                          [](const char*, size_t) {}, cancel);
        if (!r.ok) util::Log("ollama preload failed: %s", r.error.c_str());
    }).detach();
}

bool ApplyResolvedModels(const std::vector<std::wstring>& installed) {
    Settings& s = Settings::shared();
    if (s.backend != TranslationBackend::Ollama || installed.empty()) return false;

    std::wstring configured = util::Widen(s.ollamaModel);
    // "qwen2.5:3b" 与 ":latest" 变体宽松匹配
    auto matches = [&](const std::wstring& m) {
        return m == configured || m == configured + L":latest";
    };
    if (std::any_of(installed.begin(), installed.end(), matches)) return false;

    util::Log("ollama model '%s' not installed, switching to '%s'",
              s.ollamaModel.c_str(), util::Narrow(installed[0]).c_str());
    s.ollamaModel = util::Narrow(installed[0]);
    s.save();
    return true;
}

bool EnsureValidDefault() {
    const Settings& s = Settings::shared();
    if (s.backend != TranslationBackend::Ollama) return false;
    std::wstring error;
    return ApplyResolvedModels(ListInstalled(s.ollamaHost, s.ollamaPort, &error));
}

std::wstring RecommendedForMemory(const std::vector<std::wstring>& installed,
                                  uint64_t physicalMemoryBytes,
                                  double* maximumParameterBillions) {
    if (installed.empty()) return {};
    const double gib = (double)physicalMemoryBytes / 1073741824.0;
    const double cap = gib < 8 ? 3 : gib < 16 ? 7 : gib < 32 ? 14 : 32;
    if (maximumParameterBillions) *maximumParameterBillions = cap;

    const std::wstring* best = nullptr;
    double bestSize = -1;
    const std::wstring* smallest = nullptr;
    double smallestSize = std::numeric_limits<double>::max();
    for (const auto& model : installed) {
        const double size = parameterBillions(model);
        if (size <= 0) continue;
        if (size < smallestSize) { smallest = &model; smallestSize = size; }
        if (size <= cap && size > bestSize) { best = &model; bestSize = size; }
    }
    return best ? *best : smallest ? *smallest : installed.front();
}

} // namespace ollamamodels
