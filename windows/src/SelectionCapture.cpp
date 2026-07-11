#include "SelectionCapture.h"
#include "Clipboard.h"
#include "Keyboard.h"
#include "Util.h"
#include <ole2.h>          // WIN32_LEAN_AND_MEAN 不带 OLE，UIA 头需要
#include <uiautomation.h>
#include <wrl/client.h>
#include <algorithm>

using Microsoft::WRL::ComPtr;

namespace capture {

namespace {

IUIAutomation* uia() {
    static ComPtr<IUIAutomation> instance = [] {
        ComPtr<IUIAutomation> p;
        CoCreateInstance(CLSID_CUIAutomation, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&p));
        return p;
    }();
    return instance.Get();
}

std::wstring fromBstr(BSTR b) {
    if (!b) return {};
    std::wstring s(b, SysStringLen(b));
    SysFreeString(b);
    return s;
}

/// 选区各行矩形的并集（SAFEARRAY of double: l,t,w,h ×N，屏幕物理像素）
bool unionBounds(IUIAutomationTextRange* range, RECT* out) {
    SAFEARRAY* sa = nullptr;
    if (FAILED(range->GetBoundingRectangles(&sa)) || !sa) return false;
    LONG lo = 0, hi = -1;
    SafeArrayGetLBound(sa, 1, &lo);
    SafeArrayGetUBound(sa, 1, &hi);
    LONG count = hi - lo + 1;
    bool ok = false;
    if (count >= 4) {
        double* data = nullptr;
        if (SUCCEEDED(SafeArrayAccessData(sa, (void**)&data))) {
            RECT u{LONG_MAX, LONG_MAX, LONG_MIN, LONG_MIN};
            for (LONG i = 0; i + 3 < count; i += 4) {
                LONG l = (LONG)data[i], t = (LONG)data[i + 1];
                LONG r = l + (LONG)data[i + 2], b = t + (LONG)data[i + 3];
                u.left = std::min(u.left, l);
                u.top = std::min(u.top, t);
                u.right = std::max(u.right, r);
                u.bottom = std::max(u.bottom, b);
            }
            if (u.right > u.left && u.bottom > u.top) { *out = u; ok = true; }
            SafeArrayUnaccessData(sa);
        }
    }
    SafeArrayDestroy(sa);
    return ok;
}

/// 焦点元素的 TextPattern 选区：文字 + 矩形
std::optional<Capture> uiaSelection(IUIAutomationElement* focused) {
    ComPtr<IUIAutomationTextPattern> tp;
    HRESULT hr = focused->GetCurrentPatternAs(UIA_TextPatternId, IID_PPV_ARGS(&tp));
    if (FAILED(hr) || !tp) {
        util::Log("uiaSelection: no TextPattern hr=0x%08lx tp=%d", hr, tp ? 1 : 0);
        return std::nullopt;
    }

    ComPtr<IUIAutomationTextRangeArray> sel;
    hr = tp->GetSelection(&sel);
    if (FAILED(hr) || !sel) {
        util::Log("uiaSelection: GetSelection hr=0x%08lx", hr);
        return std::nullopt;
    }
    int count = 0;
    sel->get_Length(&count);
    if (count <= 0) return std::nullopt;

    ComPtr<IUIAutomationTextRange> range;
    if (FAILED(sel->GetElement(0, &range)) || !range) return std::nullopt;

    BSTR b = nullptr;
    if (FAILED(range->GetText(-1, &b))) return std::nullopt;
    std::wstring text = fromBstr(b);
    if (util::Trim(text).empty()) return std::nullopt;

    Capture cap;
    cap.text = std::move(text);
    cap.hasAnchor = unionBounds(range.Get(), &cap.anchor);
    return cap;
}

/// 焦点元素整个值（ValuePattern 优先，退回 TextPattern 文档全文）
std::optional<std::wstring> uiaWholeValue(IUIAutomationElement* focused) {
    ComPtr<IUIAutomationValuePattern> vp;
    if (SUCCEEDED(focused->GetCurrentPatternAs(UIA_ValuePatternId, IID_PPV_ARGS(&vp))) && vp) {
        BSTR b = nullptr;
        if (SUCCEEDED(vp->get_CurrentValue(&b))) {
            std::wstring v = fromBstr(b);
            if (!util::Trim(v).empty()) return v;
        }
    }
    ComPtr<IUIAutomationTextPattern> tp;
    if (SUCCEEDED(focused->GetCurrentPatternAs(UIA_TextPatternId, IID_PPV_ARGS(&tp))) && tp) {
        ComPtr<IUIAutomationTextRange> doc;
        if (SUCCEEDED(tp->get_DocumentRange(&doc)) && doc) {
            BSTR b = nullptr;
            if (SUCCEEDED(doc->GetText(-1, &b))) {
                std::wstring v = fromBstr(b);
                if (!util::Trim(v).empty()) return v;
            }
        }
    }
    return std::nullopt;
}

ComPtr<IUIAutomationElement> focusedElement() {
    ComPtr<IUIAutomationElement> el;
    if (IUIAutomation* a = uia()) a->GetFocusedElement(&el);
    return el;
}

/// 元素自身屏幕矩形（整框改写的锚点）
bool elementRect(IUIAutomationElement* el, RECT* out) {
    RECT r{};
    if (SUCCEEDED(el->get_CurrentBoundingRectangle(&r)) && r.right > r.left && r.bottom > r.top) {
        *out = r;
        return true;
    }
    return false;
}

/// 模拟 Ctrl+C 复制兜底；用后还原剪贴板
std::optional<std::wstring> copyViaClipboard() {
    clipboard::Snapshot saved = clipboard::Take();
    DWORD before = clipboard::SequenceNumber();

    keyboard::SendCopy();

    std::optional<std::wstring> result;
    // 最多等 ~400ms 让目标应用写入剪贴板
    int waited = 0;
    for (int i = 0; i < 20; ++i) {
        Sleep(20);
        waited += 20;
        if (clipboard::SequenceNumber() != before) {
            result = clipboard::GetText();
            break;
        }
    }
    util::Log("copyViaClipboard seqChanged=%d waited=%dms got_len=%d",
              clipboard::SequenceNumber() != before, waited, result ? (int)result->size() : -1);
    clipboard::Restore(saved);
    if (result && util::Trim(*result).empty()) result.reset();
    return result;
}

} // namespace

RECT CursorAnchor() {
    POINT p{};
    GetCursorPos(&p);
    return RECT{p.x, p.y - 4, p.x + 1, p.y + 14};
}

std::optional<Capture> UIASelectionOnly() {
    ComPtr<IUIAutomationElement> el = focusedElement();
    if (!el) return std::nullopt;
    return uiaSelection(el.Get());
}

std::optional<Capture> ReadSelection() {
    ComPtr<IUIAutomationElement> el = focusedElement();
    util::Log("ReadSelection focused=%d", el ? 1 : 0);
    if (el) {
        auto cap = uiaSelection(el.Get());
        util::Log("ReadSelection uia=%d", cap.has_value());
        if (cap) return cap;
    }
    if (auto copied = copyViaClipboard()) {
        Capture cap;
        cap.text = *copied;
        cap.anchor = CursorAnchor();
        cap.hasAnchor = true;
        return cap;
    }
    return std::nullopt;
}

std::optional<Capture> CaptureForRewrite() {
    ComPtr<IUIAutomationElement> el = focusedElement();
    if (el) {
        // 有选区 → 只改选区
        if (auto cap = uiaSelection(el.Get())) return cap;
        // 无选区 → 改整个输入框
        if (auto value = uiaWholeValue(el.Get())) {
            Capture cap;
            cap.text = *value;
            cap.isWholeField = true;
            cap.hasAnchor = elementRect(el.Get(), &cap.anchor);
            return cap;
        }
    }
    // UIA 拿不到 → 兜底复制（按选区处理）
    if (auto copied = copyViaClipboard()) {
        Capture cap;
        cap.text = *copied;
        cap.anchor = CursorAnchor();
        cap.hasAnchor = true;
        return cap;
    }
    return std::nullopt;
}

} // namespace capture
