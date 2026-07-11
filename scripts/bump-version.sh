#!/bin/sh
#
# bump-version.sh — 双端共享版本号的唯一入口。
#
# 用法:
#   ./scripts/bump-version.sh            # patch +1   (0.1.0 -> 0.1.1)
#   ./scripts/bump-version.sh --minor    # minor +1   (0.1.1 -> 0.2.0)
#   ./scripts/bump-version.sh --major    # major +1   (0.2.0 -> 1.0.0)
#   ./scripts/bump-version.sh 1.2.3      # 指定版本
#
# 版本号唯一来源是根目录 VERSION 文件；本脚本同步写入：
#   - macos/Saypick.xcodeproj/project.pbxproj  (MARKETING_VERSION)
#   - windows/CMakeLists.txt                   (project VERSION)
#   - windows/src/Saypick.rc                   (FILEVERSION / 字符串)
#   - windows/src/Saypick.manifest             (assemblyIdentity version)
#
# macOS 的 build number (CURRENT_PROJECT_VERSION) 独立管理，
# 仍用 macos/scripts/increment-build.sh。

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$ROOT/VERSION"

CURRENT="$(tr -d ' \r\n' < "$VERSION_FILE")"
MAJOR="${CURRENT%%.*}"
REST="${CURRENT#*.}"
MINOR="${REST%%.*}"
PATCH="${REST#*.}"

case "${1:-}" in
    "")        NEW="$MAJOR.$MINOR.$((PATCH + 1))" ;;
    --minor)   NEW="$MAJOR.$((MINOR + 1)).0" ;;
    --major)   NEW="$((MAJOR + 1)).0.0" ;;
    --help|-h) sed -n '2,20p' "$0"; exit 0 ;;
    *)
        echo "$1" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || { echo "invalid version: $1" >&2; exit 1; }
        NEW="$1"
        ;;
esac

NEW_MAJOR="${NEW%%.*}"
NEW_REST="${NEW#*.}"
NEW_MINOR="${NEW_REST%%.*}"
NEW_PATCH="${NEW_REST#*.}"

echo "$NEW" > "$VERSION_FILE"

# 注：sed -i.bumpbak 后手动删备份，是 BSD(macOS)/GNU sed 唯一通用的原地写法

# macOS
sed -i.bumpbak -E "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $NEW;/g" \
    "$ROOT/macos/Saypick.xcodeproj/project.pbxproj"
rm -f "$ROOT/macos/Saypick.xcodeproj/project.pbxproj.bumpbak"

# Windows: CMake
sed -i.bumpbak -E "s/^project\(Saypick VERSION [0-9.]+/project(Saypick VERSION $NEW/" \
    "$ROOT/windows/CMakeLists.txt"
rm -f "$ROOT/windows/CMakeLists.txt.bumpbak"

# Windows: 资源版本
sed -i.bumpbak -E \
    -e "s/FILEVERSION [0-9]+,[0-9]+,[0-9]+,[0-9]+/FILEVERSION $NEW_MAJOR,$NEW_MINOR,$NEW_PATCH,0/" \
    -e "s/PRODUCTVERSION [0-9]+,[0-9]+,[0-9]+,[0-9]+/PRODUCTVERSION $NEW_MAJOR,$NEW_MINOR,$NEW_PATCH,0/" \
    -e "s/(\"FileVersion\", \")[0-9.]+/\1$NEW/" \
    -e "s/(\"ProductVersion\", \")[0-9.]+/\1$NEW/" \
    "$ROOT/windows/src/Saypick.rc"
rm -f "$ROOT/windows/src/Saypick.rc.bumpbak"

# Windows: manifest —— 只改应用自身的 assemblyIdentity，
# 千万别碰 Common-Controls 依赖的 version="6.0.0.0"（改了会 SxS 启动失败）
sed -i.bumpbak -E "s/(version=\")[0-9.]+(\" processorArchitecture=\"\*\" name=\"everettjf.Saypick\")/\1$NEW.0\2/" \
    "$ROOT/windows/src/Saypick.manifest"
rm -f "$ROOT/windows/src/Saypick.manifest.bumpbak"

echo "version: $CURRENT -> $NEW"
echo "synced:  VERSION, macos pbxproj, windows CMakeLists/rc/manifest"
echo "next:    review with 'git diff', commit, then release with"
echo "         scripts/release-windows.ps1 (on Windows) / scripts/release-macos.sh (on macOS)"
