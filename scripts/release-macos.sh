#!/bin/bash
#
# 发布 macOS 版到 GitHub Releases（在 Mac 上运行）。
# 版本号 = 根目录 VERSION（先用 scripts/bump-version.sh 递增并提交）。
# release 不存在则创建（macOS 先发就由它建 tag），已存在则把 DMG 补传上去
# （Windows 先发过同版本时走这条路）。
#
# 前置：
#   - gh 已登录（gh auth login）
#   - 已导出 APPLE_ID、APPLE_SPECIFIC_PASSWORD、APPLE_TEAM_ID
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d ' \r\n' < "$ROOT/VERSION")"
TAG="v$VERSION"

command -v gh >/dev/null || { echo "gh not installed — brew install gh" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh is not authenticated — run: gh auth login" >&2; exit 1; }

# 提醒：pbxproj 的 MARKETING_VERSION 应已由 bump-version.sh 同步
PBX_VERSION="$(grep -m1 -Eo 'MARKETING_VERSION = [^;]+' "$ROOT/macos/Saypick.xcodeproj/project.pbxproj" | awk '{print $3}')"
if [ "$PBX_VERSION" != "$VERSION" ]; then
    echo "warning: pbxproj MARKETING_VERSION ($PBX_VERSION) != VERSION ($VERSION); run scripts/bump-version.sh $VERSION" >&2
    exit 1
fi

# 构建签名 + 公证 DMG
cd "$ROOT/macos"
./scripts/build-release.sh

DMG="$ROOT/macos/build/Saypick-$VERSION.dmg"
[ -f "$DMG" ] || { echo "DMG not produced at $DMG" >&2; exit 1; }
NAMED_DMG="$ROOT/macos/build/Saypick-$VERSION.dmg"

# release 不存在则创建
if ! gh release view "$TAG" --repo everettjf/Saypick >/dev/null 2>&1; then
    echo "creating release $TAG"
    gh release create "$TAG" --repo everettjf/Saypick --title "Saypick $VERSION" \
        --notes "Saypick $VERSION — system-wide AI translation & inline rewrite.

- macOS: download **Saypick-$VERSION.dmg**
- Windows: download and run **Saypick-Setup-$VERSION.exe** (uploaded separately if not yet present)"
else
    echo "release $TAG exists — uploading macOS asset to it"
fi

gh release upload "$TAG" "$NAMED_DMG" --repo everettjf/Saypick --clobber

echo
echo "released: https://github.com/everettjf/Saypick/releases/tag/$TAG"
