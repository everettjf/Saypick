#include "TextReplacer.h"
#include "Clipboard.h"
#include "Keyboard.h"

namespace replacer {

void Replace(const std::wstring& text, bool selectAll) {
    clipboard::Snapshot saved = clipboard::Take();

    clipboard::SetText(text);

    if (selectAll) {
        keyboard::SendSelectAll();
        Sleep(40);
    }
    keyboard::SendPaste();

    // 等粘贴完成再还原剪贴板，避免还原把待粘贴内容覆盖掉
    Sleep(150);
    clipboard::Restore(saved);
}

} // namespace replacer
