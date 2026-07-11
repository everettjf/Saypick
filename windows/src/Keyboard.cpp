#include "Keyboard.h"
#include <vector>

namespace keyboard {

namespace {

void addKey(std::vector<INPUT>& seq, WORD vk, bool down) {
    INPUT in{};
    in.type = INPUT_KEYBOARD;
    in.ki.wVk = vk;
    in.ki.dwFlags = down ? 0 : KEYEVENTF_KEYUP;
    seq.push_back(in);
}

} // namespace

void SendCtrlCombo(WORD vk) {
    std::vector<INPUT> seq;

    // 先按下 Ctrl，再抬起用户仍按着的修饰键（如触发热键的 Alt）。
    // 顺序很关键：孤立的 Alt↓→Alt↑ 会让目标窗口进入菜单激活模式，
    // 吃掉随后的 Ctrl+C；中间有 Ctrl 介入则不会。
    addKey(seq, VK_CONTROL, true);

    const WORD holdable[] = {VK_MENU, VK_SHIFT, VK_LWIN, VK_RWIN};
    for (WORD m : holdable) {
        if (GetAsyncKeyState(m) & 0x8000) addKey(seq, m, false);
    }

    addKey(seq, vk, true);
    addKey(seq, vk, false);
    addKey(seq, VK_CONTROL, false);

    SendInput((UINT)seq.size(), seq.data(), sizeof(INPUT));
}

} // namespace keyboard
