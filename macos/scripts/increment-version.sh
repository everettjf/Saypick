#!/bin/bash
#
# increment-version.sh
# 递增 Version 的最后一位 (MARKETING_VERSION)
#
# 使用方法:
#   ./scripts/increment-version.sh
#
# 示例:
#   1.0.0 → 1.0.1
#   1.2.5 → 1.2.6
#
# 注意: 版本号存储在 project.pbxproj 中，Info.plist 通过变量引用
#

set -e

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PBXPROJ_PATH="$PROJECT_ROOT/Saypick.xcodeproj/project.pbxproj"

# 检查 project.pbxproj 是否存在
if [ ! -f "$PBXPROJ_PATH" ]; then
    echo -e "${RED}❌ project.pbxproj not found at $PBXPROJ_PATH${NC}"
    exit 1
fi

# 从 project.pbxproj 获取当前 Version
CURRENT_VERSION=$(grep "MARKETING_VERSION = " "$PBXPROJ_PATH" | head -1 | sed 's/.*= \(.*\);/\1/')

# 分割版本号
IFS='.' read -ra VERSION_PARTS <<< "$CURRENT_VERSION"

# 确保有足够的部分
if [ ${#VERSION_PARTS[@]} -lt 1 ]; then
    echo -e "${RED}❌ Invalid version format: $CURRENT_VERSION${NC}"
    exit 1
fi

# 递增最后一位
LAST_INDEX=$((${#VERSION_PARTS[@]} - 1))
VERSION_PARTS[$LAST_INDEX]=$((${VERSION_PARTS[$LAST_INDEX]} + 1))

# 重新组合版本号
NEW_VERSION=$(IFS='.'; echo "${VERSION_PARTS[*]}")

# 更新 project.pbxproj (同时更新 Debug 和 Release 配置)
# 需要转义点号，因为 sed 中点号是正则表达式的特殊字符
CURRENT_VERSION_ESCAPED=$(echo "$CURRENT_VERSION" | sed 's/\./\\./g')
sed -i '' "s/MARKETING_VERSION = $CURRENT_VERSION_ESCAPED;/MARKETING_VERSION = $NEW_VERSION;/g" "$PBXPROJ_PATH"

echo -e "${BLUE}ℹ️  Version:${NC} $CURRENT_VERSION → ${GREEN}$NEW_VERSION${NC}"
echo -e "${GREEN}✅ Version incremented successfully${NC}"
