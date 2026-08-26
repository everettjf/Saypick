#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() {
    echo "ui-quality: $1" >&2
    exit 1
}

# Keep the shared brand accent aligned across SwiftUI and Win32.
rg -q '0x7C / 255.*0x5C / 255.*0xFF / 255' macos/TypeTide/Config/TypeTideTheme.swift \
    || fail "macOS brand accent token changed unexpectedly"
rg -q 'Accent = RGB\(0x7C, 0x5C, 0xFF\)' windows/src/UITheme.h \
    || fail "Windows brand accent token changed unexpectedly"

# Custom clickable SwiftUI surfaces must remain Buttons, not tap gestures.
if rg -n '\.onTapGesture' macos/TypeTide/UI macos/TypeTide/Views; then
    fail "use Button for tappable SwiftUI UI"
fi

# Avoid reintroducing APIs already superseded across supported macOS versions.
if rg -n '\.(foregroundColor|cornerRadius)\(' macos/TypeTide/UI; then
    fail "use semantic foregroundStyle/clipShape in custom UI"
fi

# Preserve the Windows common-controls v6 dependency required for native styling.
rg -q 'version="6\.0\.0\.0"' windows/src/TypeTide.manifest \
    || fail "Windows Common-Controls v6 manifest entry is missing"

echo "ui-quality: passed"
