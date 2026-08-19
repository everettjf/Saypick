#include "LocalDiagnostics.h"
#include "Json.h"
#include "Util.h"
#include <algorithm>
#include <chrono>
#include <fstream>
#include <mutex>
#include <sstream>

namespace diagnostics {
namespace {
std::mutex g_mutex;
constexpr size_t kMaximumEvents = 500;

json::Array loadUnlocked() {
    std::ifstream file(Path(), std::ios::binary);
    if (!file) return {};
    std::stringstream buffer;
    buffer << file.rdbuf();
    bool ok = false;
    json::Value root = json::Parse(buffer.str(), &ok);
    if (!ok || !root.isArray()) return {};
    return *root.array();
}
} // namespace

std::wstring Path() { return util::AppDataDir() + L"\\diagnostics.json"; }

void Record(const std::string& name, const std::string& outcome,
            const std::string& backend, const std::string& captureMethod,
            const std::string& errorCategory, int firstTokenMs,
            int totalMs, int inputCharacterCount) {
    std::lock_guard lock(g_mutex);
    json::Array events = loadUnlocked();
    json::Object event;
    auto now = std::chrono::system_clock::now().time_since_epoch();
    event["timestampUnixMs"] = (double)std::chrono::duration_cast<std::chrono::milliseconds>(now).count();
    event["platform"] = "Windows";
    event["name"] = name;
    event["outcome"] = outcome;
    if (!backend.empty()) event["backend"] = backend;
    if (!captureMethod.empty()) event["captureMethod"] = captureMethod;
    if (!errorCategory.empty()) event["errorCategory"] = errorCategory;
    if (firstTokenMs >= 0) event["firstTokenMilliseconds"] = firstTokenMs;
    if (totalMs >= 0) event["totalMilliseconds"] = totalMs;
    if (inputCharacterCount >= 0) event["inputCharacterCount"] = inputCharacterCount;
    events.push_back(json::Value(std::move(event)));
    if (events.size() > kMaximumEvents)
        events.erase(events.begin(), events.begin() + (events.size() - kMaximumEvents));

    const std::wstring temp = Path() + L".tmp";
    std::ofstream out(temp, std::ios::binary | std::ios::trunc);
    if (!out) return;
    out << json::Value(std::move(events)).dump();
    out.close();
    if (!out) { DeleteFileW(temp.c_str()); return; }
    MoveFileExW(temp.c_str(), Path().c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH);
}

void Clear() {
    std::lock_guard lock(g_mutex);
    DeleteFileW(Path().c_str());
}

} // namespace diagnostics
