#include "Settings.h"
#include "Json.h"
#include "Util.h"
#include <fstream>
#include <sstream>

std::wstring Hotkey::displayString() const {
    std::wstring s;
    if (modifiers & MOD_CONTROL) s += L"Ctrl+";
    if (modifiers & MOD_SHIFT) s += L"Shift+";
    if (modifiers & MOD_ALT) s += L"Alt+";
    if (modifiers & MOD_WIN) s += L"Win+";

    wchar_t name[64]{};
    UINT scan = MapVirtualKeyW(vk, MAPVK_VK_TO_VSC);
    LONG l = (LONG)(scan << 16);
    switch (vk) {  // 扩展键需要置扩展位才能取到正确名字
    case VK_LEFT: case VK_RIGHT: case VK_UP: case VK_DOWN:
    case VK_HOME: case VK_END: case VK_PRIOR: case VK_NEXT:
    case VK_INSERT: case VK_DELETE:
        l |= 1 << 24; break;
    }
    if (GetKeyNameTextW(l, name, 64) > 0) s += name;
    else s += (wchar_t)vk;
    return s;
}

Settings& Settings::shared() {
    static Settings s = [] {
        Settings v;
        v.load();
        return v;
    }();
    return s;
}

std::wstring Settings::filePath() {
    return util::AppDataDir() + L"\\settings.json";
}

void Settings::load() {
    std::ifstream f(filePath(), std::ios::binary);
    if (!f) return;
    std::stringstream ss;
    ss << f.rdbuf();
    bool ok = false;
    json::Value root = json::Parse(ss.str(), &ok);
    if (!ok || !root.isObject()) return;

    auto str = [&](const char* k, const std::string& def) {
        return root[k].isString() ? root[k].asString() : def;
    };
    auto boolean = [&](const char* k, bool def) {
        return root[k].type() == json::Value::Type::Bool ? root[k].asBool() : def;
    };

    enabled = boolean("enabled", enabled);
    backend = str("backend", "ollama") == "openai" ? TranslationBackend::OpenAI : TranslationBackend::Ollama;

    ollamaHost = str("ollamaHost", ollamaHost);
    ollamaPort = root["ollamaPort"].isNull() ? ollamaPort : root["ollamaPort"].asInt(ollamaPort);
    ollamaModel = str("ollamaModel", ollamaModel);

    openAIBaseURL = str("openAIBaseURL", openAIBaseURL);
    openAIKey = str("openAIKey", openAIKey);
    openAIModel = str("openAIModel", openAIModel);

    if (auto l = lang::FromCode(str("nativeLanguage", ""))) nativeLanguage = *l;
    if (auto l = lang::FromCode(str("foreignLanguage", ""))) foreignLanguage = *l;
    if (auto d = lang::DirectionFromCode(str("readDirection", ""))) readDirection = *d;
    if (auto d = lang::DirectionFromCode(str("rewriteDirection", ""))) rewriteDirection = *d;

    auto loadHotkey = [&](const char* k, Hotkey& hk) {
        const json::Value& v = root[k];
        if (v.isObject()) {
            hk.modifiers = (UINT)v["modifiers"].asInt((int)hk.modifiers);
            hk.vk = (UINT)v["vk"].asInt((int)hk.vk);
        }
    };
    loadHotkey("readShortcut", readShortcut);
    loadHotkey("rewriteShortcut", rewriteShortcut);

    std::string trig = str("selectionTrigger", "none");
    selectionTrigger = trig == "icon" ? SelectionTrigger::Icon
                     : trig == "auto" ? SelectionTrigger::Auto
                     : SelectionTrigger::None;
    rewritePreview = boolean("rewritePreview", rewritePreview);
    if (auto s2 = lang::StyleFromCode(str("readStyle", ""))) readStyle = *s2;
    if (auto s2 = lang::StyleFromCode(str("rewriteStyle", ""))) rewriteStyle = *s2;

    skipApps.clear();
    if (const json::Array* arr = root["skipApps"].array())
        for (auto& item : *arr)
            if (item.isString()) skipApps.push_back(util::Widen(item.asString()));

    hasCompletedFirstLaunch = boolean("hasCompletedFirstLaunch", false);
    lastUpdateCheck = (long long)root["lastUpdateCheck"].asNumber(0);
}

void Settings::save() const {
    json::Object root;
    root["enabled"] = enabled;
    root["backend"] = backend == TranslationBackend::OpenAI ? "openai" : "ollama";

    root["ollamaHost"] = ollamaHost;
    root["ollamaPort"] = ollamaPort;
    root["ollamaModel"] = ollamaModel;

    root["openAIBaseURL"] = openAIBaseURL;
    root["openAIKey"] = openAIKey;
    root["openAIModel"] = openAIModel;

    root["nativeLanguage"] = lang::Code(nativeLanguage);
    root["foreignLanguage"] = lang::Code(foreignLanguage);
    root["readDirection"] = lang::DirectionCode(readDirection);
    root["rewriteDirection"] = lang::DirectionCode(rewriteDirection);

    auto hotkeyJson = [](const Hotkey& hk) {
        json::Object o;
        o["modifiers"] = (int)hk.modifiers;
        o["vk"] = (int)hk.vk;
        return json::Value(std::move(o));
    };
    root["readShortcut"] = hotkeyJson(readShortcut);
    root["rewriteShortcut"] = hotkeyJson(rewriteShortcut);

    root["selectionTrigger"] = selectionTrigger == SelectionTrigger::Icon ? "icon"
                             : selectionTrigger == SelectionTrigger::Auto ? "auto"
                             : "none";
    root["rewritePreview"] = rewritePreview;
    root["readStyle"] = lang::StyleCode(readStyle);
    root["rewriteStyle"] = lang::StyleCode(rewriteStyle);

    json::Array apps;
    for (auto& a : skipApps) apps.push_back(util::Narrow(a));
    root["skipApps"] = json::Value(std::move(apps));

    root["hasCompletedFirstLaunch"] = hasCompletedFirstLaunch;
    root["lastUpdateCheck"] = (double)lastUpdateCheck;

    std::ofstream f(filePath(), std::ios::binary | std::ios::trunc);
    if (f) f << json::Value(std::move(root)).dump();
}
