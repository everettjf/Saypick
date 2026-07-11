#!/bin/bash
#
# increment-build.sh
# 递增 Build Number (CURRENT_PROJECT_VERSION)
#
# 使用方法:
#   ./scripts/increment-build.sh
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

# 从 project.pbxproj 获取当前 Build Number
CURRENT_BUILD=$(grep "CURRENT_PROJECT_VERSION = " "$PBXPROJ_PATH" | head -1 | sed 's/.*= \([0-9]*\);/\1/')

# 如果是空字符串或非数字，设置为 0
if [ -z "$CURRENT_BUILD" ] || ! [[ "$CURRENT_BUILD" =~ ^[0-9]+$ ]]; then
    echo -e "${BLUE}ℹ️  Current build is empty or invalid, starting from 0${NC}"
    CURRENT_BUILD=0
fi

# 递增 Build Number
NEW_BUILD=$((CURRENT_BUILD + 1))

# 更新 project.pbxproj (同时更新 Debug 和 Release 配置)
sed -i '' "s/CURRENT_PROJECT_VERSION = $CURRENT_BUILD;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" "$PBXPROJ_PATH"

echo -e "${BLUE}ℹ️  Build Number:${NC} $CURRENT_BUILD → ${GREEN}$NEW_BUILD${NC}"
echo -e "${GREEN}✅ Build number incremented successfully${NC}"
