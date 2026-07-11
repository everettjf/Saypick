#include "SelfTest.h"
#include "Json.h"
#include "Language.h"
#include "OllamaModels.h"
#include "Settings.h"
#include "Translator.h"
#include "Util.h"
#include <cstdio>
#include <string>

namespace {

int g_failures = 0;

void check(bool cond, const char* name, const std::string& detail = {}) {
    if (cond) {
        printf("  ok   %s\n", name);
    } else {
        ++g_failures;
        printf("  FAIL %s%s%s\n", name, detail.empty() ? "" : " — ", detail.c_str());
    }
}

void testJson() {
    printf("[json]\n");
    bool ok = false;
    json::Value v = json::Parse(R"({"a":1,"b":"xé\n","c":[true,null,2.5],"d":{"e":"中文"}})", &ok);
    check(ok, "parse");
    check(v["a"].asInt() == 1, "int");
    check(v["b"].asString() == "x\xC3\xA9\n", "escaped string");
    check(v["c"].size() == 3 && v["c"].at(0).asBool(), "array");
    check(v["d"]["e"].asString() == "中文", "nested utf8");

    std::string dumped = v.dump();
    bool ok2 = false;
    json::Value round = json::Parse(dumped, &ok2);
    check(ok2 && round["d"]["e"].asString() == "中文", "roundtrip");

    json::Parse("{bad json", &ok);
    check(!ok, "reject malformed");

    // SSE delta 场景
    json::Value sse = json::Parse(R"({"choices":[{"delta":{"content":"你好"}}]})", &ok);
    check(ok && sse["choices"].at(0)["delta"]["content"].asString() == "你好", "sse delta shape");
}

void testDetect() {
    printf("[language detect]\n");
    auto is = [](std::optional<Language> got, Language want) { return got && *got == want; };
    check(is(lang::Detect(L"今天天气怎么样？我想出去散步。"), Language::Chinese), "zh");
    check(is(lang::Detect(L"The quick brown fox jumps over the lazy dog and it was great."), Language::English), "en");
    check(is(lang::Detect(L"Это очень интересная книга о русской истории."), Language::Russian), "ru");
    check(is(lang::Detect(L"مرحبا كيف حالك اليوم؟"), Language::Arabic), "ar");
    check(is(lang::Detect(L"El perro corre por el parque y los niños juegan con una pelota."), Language::Spanish), "es");
    check(is(lang::Detect(L"Le chat est sur la table et il ne veut pas descendre du tout."), Language::French), "fr");
    check(is(lang::Detect(L"आप कैसे हैं? मुझे हिंदी बहुत पसंद है।"), Language::Hindi), "hi");
    check(!lang::Detect(L"12345 !!! ???").has_value(), "digits → unknown");
    check(!lang::Detect(L"").has_value(), "empty → unknown");
}

void testSettings() {
    printf("[settings]\n");
    // 隔离到子目录，避免覆盖外层准备好的 settings.json（live translate 用）
    std::wstring outer = util::AppDataDir();
    SetEnvironmentVariableW(L"SAYPICK_DATA_DIR", (outer + L"\\selftest-settings").c_str());

    Settings s;
    s.enabled = false;
    s.backend = TranslationBackend::OpenAI;
    s.openAIBaseURL = "http://127.0.0.1:8199/v1";
    s.openAIKey = "test-key";
    s.openAIModel = "test-model";
    s.nativeLanguage = Language::French;
    s.foreignLanguage = Language::Russian;
    s.readDirection = TranslationDirection::ForeignToNative;
    s.readShortcut = {MOD_CONTROL | MOD_SHIFT, 'T'};
    s.selectionTrigger = SelectionTrigger::Icon;
    s.rewritePreview = true;
    s.rewriteStyle = RewriteStyle::Polished;
    s.skipApps = {L"notepad", L"code.exe"};
    s.save();

    Settings loaded;
    loaded.load();
    check(loaded.enabled == false, "enabled");
    check(loaded.backend == TranslationBackend::OpenAI, "backend");
    check(loaded.openAIBaseURL == "http://127.0.0.1:8199/v1", "base url");
    check(loaded.nativeLanguage == Language::French && loaded.foreignLanguage == Language::Russian, "languages");
    check(loaded.readDirection == TranslationDirection::ForeignToNative, "direction");
    check(loaded.readShortcut == Hotkey{MOD_CONTROL | MOD_SHIFT, 'T'}, "hotkey");
    check(loaded.selectionTrigger == SelectionTrigger::Icon, "trigger");
    check(loaded.rewritePreview && loaded.rewriteStyle == RewriteStyle::Polished, "behavior");
    check(loaded.skipApps.size() == 2 && loaded.skipApps[1] == L"code.exe", "skip apps");

    check(Hotkey{MOD_ALT, 'D'}.displayString() == L"Alt+D", "hotkey display",
          util::Narrow(Hotkey{MOD_ALT, 'D'}.displayString()));

    SetEnvironmentVariableW(L"SAYPICK_DATA_DIR", outer.c_str());
}

void testPrompts() {
    printf("[prompts]\n");
    std::string sys = translator::SystemPrompt(Language::English, Language::Chinese, RewriteStyle::Formal);
    check(sys.find("from Chinese into English") != std::string::npos, "system from/to", sys);
    check(sys.find("professional, formal tone") != std::string::npos, "style injected");
    std::string sys2 = translator::SystemPrompt(Language::Chinese, std::nullopt, RewriteStyle::Faithful);
    check(sys2.find("the detected language") != std::string::npos, "auto source");
    check(sys2.find("tone") == std::string::npos, "faithful = no style line");
    std::string plain = translator::PlainPrompt(L"你好", Language::English, Language::Chinese, RewriteStyle::Faithful);
    check(plain.find("你好") != std::string::npos, "plain contains text");
}

void testOllamaModels() {
    printf("[ollama models] (live)\n");
    Settings::shared().load();
    if (Settings::shared().backend != TranslationBackend::Ollama) {
        printf("  skip (backend is not ollama)\n");
        return;
    }
    std::wstring err;
    auto models = ollamamodels::ListInstalled(&err);
    check(!models.empty(), "list installed models", util::Narrow(err));
    for (auto& m : models) printf("  installed: %s\n", util::Narrow(m).c_str());

    // 自动纠正：配置成不存在的模型 → 应替换成第一个已装模型（并落盘，
    // 后面的 live translate 直接用纠正后的模型）
    Settings& s = Settings::shared();
    s.ollamaModel = "definitely-not-installed:0b";
    bool changed = ollamamodels::EnsureValidDefault();
    check(changed && s.ollamaModel != "definitely-not-installed:0b",
          "auto-resolve missing model", s.ollamaModel);
    printf("  resolved to: %s\n", s.ollamaModel.c_str());
}

void testLiveTranslate() {
    printf("[live translate] (backend from settings.json)\n");
    Settings::shared().load();
    std::wstring err;
    auto result = translator::TranslateFully(
        {L"你好，世界", std::optional<Language>(Language::Chinese), Language::English, RewriteStyle::Faithful}, &err);
    check(result.has_value(), "translate", util::Narrow(err));
    if (result) {
        printf("  result: %s\n", util::Narrow(*result).c_str());
        // 缓存命中路径
        auto again = translator::TranslateFully(
            {L"你好，世界", std::optional<Language>(Language::Chinese), Language::English, RewriteStyle::Faithful}, &err);
        check(again == result, "cache hit identical");
    }
}

} // namespace

int RunSelfTests(bool includeLiveTranslate) {
    printf("Saypick self-test (v%s)\n", SAYPICK_VERSION_STRING);
    testJson();
    testDetect();
    testSettings();
    testPrompts();
    if (includeLiveTranslate) {
        testOllamaModels();
        testLiveTranslate();
    }
    printf(g_failures ? "\n%d FAILURE(S)\n" : "\nall tests passed\n", g_failures);
    return g_failures;
}
