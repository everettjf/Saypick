#pragma once

#include <windows.h>

namespace ui {

// Cross-platform TypeTide brand and semantic colors. Native Win32 controls
// retain system behavior while custom-drawn surfaces share these tokens.
constexpr COLORREF Accent = RGB(0x7C, 0x5C, 0xFF);
constexpr COLORREF AccentText = RGB(0xFF, 0xFF, 0xFF);
constexpr COLORREF Success = RGB(0x20, 0x9B, 0x4B);
constexpr COLORREF WarningLight = RGB(0xD9, 0x77, 0x06);
constexpr COLORREF WarningDark = RGB(0xFF, 0xA5, 0x4C);
constexpr COLORREF DangerLight = RGB(0xC4, 0x2B, 0x1C);
constexpr COLORREF DangerDark = RGB(0xFF, 0x6B, 0x62);

namespace spacing {
constexpr int XSmall = 4;
constexpr int Small = 8;
constexpr int Medium = 12;
constexpr int Large = 16;
constexpr int XLarge = 24;
constexpr int Page = 28;
}

namespace radius {
constexpr int Control = 8;
constexpr int Card = 10;
constexpr int Popup = 12;
}

namespace control {
constexpr int CompactHeight = 28;
constexpr int MinimumHitSize = 28;
constexpr int PopupMinWidth = 360;
constexpr int PopupIdealWidth = 400;
constexpr int PopupMaxWidth = 520;
}

struct Palette {
    COLORREF background;
    COLORREF surface;
    COLORREF text;
    COLORREF secondary;
    COLORREF divider;
    COLORREF button;
    COLORREF buttonBorder;
    COLORREF warning;
    COLORREF danger;
};

inline Palette palette(bool dark) {
    if (dark) {
        return {RGB(0x20, 0x20, 0x22), RGB(0x2B, 0x2B, 0x2E),
                RGB(0xF2, 0xF2, 0xF4), RGB(0xB0, 0xB0, 0xB8),
                RGB(0x45, 0x45, 0x4A), RGB(0x3A, 0x3A, 0x3F),
                RGB(0x55, 0x55, 0x5A), WarningDark, DangerDark};
    }
    return {RGB(0xF3, 0xF3, 0xF3), RGB(0xFF, 0xFF, 0xFF),
            RGB(0x20, 0x20, 0x24), RGB(0x67, 0x67, 0x72),
            RGB(0xE4, 0xE4, 0xE8), RGB(0xF2, 0xF2, 0xF5),
            RGB(0xD5, 0xD5, 0xDA), WarningLight, DangerLight};
}

} // namespace ui
