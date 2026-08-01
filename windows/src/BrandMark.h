#pragma once
#include <windows.h>
#include <algorithm>

namespace brand {

/// 单色 TypeTide 标记：点阵汇聚成潮头。适用于托盘外的小尺寸 GDI 界面。
inline void DrawMark(HDC dc, RECT bounds, COLORREF color) {
    const int width = std::max<LONG>(1, bounds.right - bounds.left);
    const int height = std::max<LONG>(1, bounds.bottom - bounds.top);
    auto x = [&](int value) { return bounds.left + MulDiv(value, width, 64); };
    auto y = [&](int value) { return bounds.top + MulDiv(value, height, 64); };

    HBRUSH brush = CreateSolidBrush(color);
    HGDIOBJ oldBrush = SelectObject(dc, brush);
    HGDIOBJ oldPen = SelectObject(dc, GetStockObject(NULL_PEN));
    auto curve = [&](int x1, int y1, int x2, int y2, int x3, int y3) {
        POINT points[] = {{x(x1), y(y1)}, {x(x2), y(y2)}, {x(x3), y(y3)}};
        PolyBezierTo(dc, points, 3);
    };

    BeginPath(dc);
    MoveToEx(dc, x(18), y(45), nullptr);
    curve(32, 45, 31, 14, 47, 15);
    curve(62, 15, 61, 34, 51, 36);
    curve(57, 28, 49, 24, 44, 28);
    curve(39, 32, 43, 45, 58, 48);
    curve(40, 52, 28, 51, 18, 45);
    CloseFigure(dc);
    EndPath(dc);
    FillPath(dc);

    constexpr int dots[][3] = {
        {8, 29, 2}, {13, 25, 2}, {18, 23, 2},
        {8, 36, 2}, {14, 34, 3}, {21, 31, 2},
        {11, 43, 2}, {17, 42, 2}, {24, 38, 3},
    };
    for (const auto& dot : dots) {
        const int radiusX = std::max(1, MulDiv(dot[2], width, 64));
        const int radiusY = std::max(1, MulDiv(dot[2], height, 64));
        Ellipse(dc, x(dot[0]) - radiusX, y(dot[1]) - radiusY,
                x(dot[0]) + radiusX + 1, y(dot[1]) + radiusY + 1);
    }

    SelectObject(dc, oldPen);
    SelectObject(dc, oldBrush);
    DeleteObject(brush);
}

} // namespace brand
