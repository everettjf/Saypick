#pragma once
#include <string>

namespace diagnostics {

// Local-only operational metadata. Never pass user text, translations, app names,
// clipboard contents, endpoint URLs, or credentials to this API.
void Record(const std::string& name, const std::string& outcome,
            const std::string& backend = {}, const std::string& captureMethod = {},
            const std::string& errorCategory = {}, int firstTokenMs = -1,
            int totalMs = -1, int inputCharacterCount = -1);
void Clear();
std::wstring Path();

} // namespace diagnostics
