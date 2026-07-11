//
//  SelectionIcon.h — 划词后贴着选区显示的小图标，点击触发翻译。
//  （对应 macOS 的 SelectionIconWindow）
//
#pragma once
#include <windows.h>
#include <functional>

class SelectionIcon {
public:
    static SelectionIcon& shared();

    /// 贴合选区右端外侧显示；选区无效时落在 fallback 点旁。
    void show(RECT selectionRect, bool rectValid, POINT fallback, std::function<void()> onTap);
    void hide();
    bool isVisible() const { return hwnd_ != nullptr; }
    /// 命中测试（划词监听需要忽略点在图标上的 mouseup）
    bool containsScreenPoint(POINT pt) const;

private:
    SelectionIcon() = default;
    static LRESULT CALLBACK wndProc(HWND, UINT, WPARAM, LPARAM);
    LRESULT handle(UINT msg, WPARAM wp, LPARAM lp);

    HWND hwnd_ = nullptr;
    std::function<void()> onTap_;
    bool hover_ = false;
    int mouseHookId_ = 0;
};
