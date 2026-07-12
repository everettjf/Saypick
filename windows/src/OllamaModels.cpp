#include "OllamaModels.h"
#include "Http.h"
#include "Json.h"
#include "Settings.h"
#include "Util.h"
#include <algorithm>
#include <thread>

namespace ollamamodels {

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

} // namespace ollamamodels
