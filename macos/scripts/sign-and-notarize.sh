#!/bin/bash
#
# sign-and-notarize.sh
# 单独对已有的 .app 或 .dmg 进行签名和公证
#
# 使用方法:
#   export APPLE_ID="you@example.com"
#   export APPLE_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
#   export APPLE_TEAM_ID="ABC1234567"
#   ./scripts/sign-and-notarize.sh /path/to/TypeTide.app
#   ./scripts/sign-and-notarize.sh /path/to/TypeTide.dmg
#

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; exit 1; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# 检查参数
if [ $# -eq 0 ]; then
    error "Usage: $0 <path-to-app-or-dmg>\nExample: $0 build/export/TypeTide.app"
fi

TARGET_PATH="$1"

# 检查文件是否存在
if [ ! -e "$TARGET_PATH" ]; then
    error "File not found: $TARGET_PATH"
fi

# 判断是 .app 还是 .dmg
if [[ "$TARGET_PATH" == *.app ]]; then
    FILE_TYPE="app"
    info "Detected: macOS Application Bundle"
elif [[ "$TARGET_PATH" == *.dmg ]]; then
    FILE_TYPE="dmg"
    info "Detected: Disk Image"
else
    error "Unsupported file type. Please provide .app or .dmg"
fi

# 发布凭据只从调用方导出的环境变量读取，不加载仓库内的密钥文件。
if [ -z "${APPLE_ID:-}" ]; then
    error "APPLE_ID is not exported"
fi

if [ -z "${APPLE_SPECIFIC_PASSWORD:-}" ]; then
    error "APPLE_SPECIFIC_PASSWORD is not exported"
fi

if [ -z "${APPLE_TEAM_ID:-}" ]; then
    error "APPLE_TEAM_ID is not exported"
fi

DEVELOPER_ID_APPLICATION="$(security find-identity -v -p codesigning |
    sed -n "s/.*\"\\(Developer ID Application:.*(${APPLE_TEAM_ID})\\)\".*/\\1/p" |
    head -1)"
if [ -z "$DEVELOPER_ID_APPLICATION" ]; then
    error "No valid Developer ID Application certificate found for team $APPLE_TEAM_ID"
fi
success "Using signing identity: $DEVELOPER_ID_APPLICATION"

# 如果是 .app，先签名
if [ "$FILE_TYPE" == "app" ]; then
    info "Signing application..."

    codesign --deep --force --verify --verbose \
        --sign "$DEVELOPER_ID_APPLICATION" \
        --options runtime \
        --timestamp \
        "$TARGET_PATH" || error "Signing failed"

    # 验证签名
    codesign --verify --deep --strict --verbose=2 "$TARGET_PATH" || error "Signature verification failed"

    success "Application signed"

    # 询问是否创建 DMG
    echo ""
    read -p "Do you want to create a DMG? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        DMG_PATH="${TARGET_PATH%.*}.dmg"
        info "Creating DMG at $DMG_PATH..."

        if ! command -v create-dmg &> /dev/null; then
            warning "create-dmg not installed. Installing via Homebrew..."
            brew install create-dmg || error "Failed to install create-dmg"
        fi

        create-dmg \
            --volname "TypeTide" \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 100 \
            --app-drop-link 450 200 \
            "$DMG_PATH" \
            "$TARGET_PATH" || error "DMG creation failed"

        success "DMG created: $DMG_PATH"
        TARGET_PATH="$DMG_PATH"
    else
        info "Skipping DMG creation"
        echo ""
        success "Signing completed. Run this script again with the DMG to notarize."
        exit 0
    fi
fi

# 公证
info "Starting notarization..."
info "Uploading to Apple (this may take several minutes)..."

NOTARIZE_OUTPUT=$(xcrun notarytool submit "$TARGET_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_SPECIFIC_PASSWORD" \
    --wait 2>&1)

echo "$NOTARIZE_OUTPUT"

# 检查公证结果
if echo "$NOTARIZE_OUTPUT" | grep -q "status: Accepted"; then
    success "Notarization succeeded"

    # 装订票据
    info "Stapling notarization ticket..."
    xcrun stapler staple "$TARGET_PATH" || error "Stapling failed"

    # 验证
    xcrun stapler validate "$TARGET_PATH" || error "Validation failed"

    success "Ticket stapled successfully"
else
    error "Notarization failed. Check output above."
fi

# 最终验证
info "Performing final Gatekeeper check..."
spctl --assess --type open --context context:primary-signature --verbose=4 "$TARGET_PATH"

echo ""
success "🎉 Signing and notarization completed!"
info "File: $TARGET_PATH"
echo ""
