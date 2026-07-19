#pragma once

#include <string>

namespace credentials {

std::string LoadCloudApiKey();
bool SaveCloudApiKey(const std::string& key);

} // namespace credentials
