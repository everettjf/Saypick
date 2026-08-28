#include "Keyboard.h"
#include "Util.h"
#include <vector>

namespace keyboard {

namespace {

void addScanKey(std::vector<INPUT>& seq, WORD vk, bool down) {
    UINT scan = MapVirtualKeyW(vk, MAPVK_VK_TO_VSC_EX);
    INPUT in{};
    in.type = INPUT_KEYBOARD;
    in.ki.wVk = 0;
    in.ki.wScan = static_cast<WORD>(scan & 0xFF);
    in.ki.dwFlags = KEYEVENTF_SCANCODE | (down ? 0 : KEYEVENTF_KEYUP);
    if (scan & 0xFF00) in.ki.dwFlags |= KEYEVENTF_EXTENDEDKEY;
    seq.push_back(in);
}

std::vector<INPUT> buildCtrlComboInputs(
    WORD vk, const std::vector<WORD>& heldModifiers) {
    std::vector<INPUT> seq;

    // 先按下 Ctrl，再抬起用户仍按着的修饰键（如触发热键的 Alt）。
    // 顺序很关键：孤立的 Alt↓→Alt↑ 会让目标窗口进入菜单激活模式，
    // 吃掉随后的 Ctrl+C；中间有 Ctrl 介入则不会。
    // Use hardware scan codes, not virtual-key-only events.  Chromium,
    // Electron, and some custom editors ignore a synthetic modifier whose
    // scan code is zero, while still accepting the following letter.  That
    // turns an intended Ctrl+V into a literal V.
    addScanKey(seq, VK_LCONTROL, true);

    for (WORD m : heldModifiers) addScanKey(seq, m, false);

    addScanKey(seq, vk, true);
    addScanKey(seq, vk, false);
    addScanKey(seq, VK_LCONTROL, false);
    return seq;
}

} // namespace

void SendCtrlCombo(WORD vk) {
    std::vector<WORD> held;
    const WORD holdable[] = {
        VK_LMENU, VK_RMENU, VK_LSHIFT, VK_RSHIFT, VK_LWIN, VK_RWIN,
    };
    for (WORD m : holdable)
        if (GetAsyncKeyState(m) & 0x8000) held.push_back(m);

    std::vector<INPUT> seq = buildCtrlComboInputs(vk, held);

    const UINT sent = SendInput((UINT)seq.size(), seq.data(), sizeof(INPUT));
    if (sent != seq.size())
        util::Log("SendCtrlCombo vk=%u sent=%u/%zu error=%lu", vk, sent, seq.size(),
                  GetLastError());
}

} // namespace keyboard
