#include "OllamaModels.h"
#include "Http.h"
#include "Json.h"
#include "Settings.h"
#include "Util.h"
#include <algorithm>

namespace ollamamodels {

std::vector<std::wstring> ListInstalled(std::wstring* error) {
    const Settings& s = Settings::shared();
    std::wstring url = util::Widen(s.ollamaHost) + L":" + std::to_wstring(s.ollamaPort) + L"/api/tags";

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

bool EnsureValidDefault() {
    Settings& s = Settings::shared();
    if (s.backend != TranslationBackend::Ollama) return false;

    std::wstring error;
    std::vector<std::wstring> installed = ListInstalled(&error);
    if (installed.empty()) return false;  // 连不上或没装模型 → 不动配置

    std::wstring configured = util::Widen(s.ollamaModel);
    // "qwen2.5:3b" 与 "qwen2.5:3b"（含 latest 变体）宽松匹配
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

} // namespace ollamamodels
