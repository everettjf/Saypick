//
//  SelectionIconWindow.swift
//  TypeTide
//
//  划词后在鼠标旁显示的小图标，点击触发翻译。
//

import AppKit
import SwiftUI

@MainActor
final class SelectionIconWindow {
    static let shared = SelectionIconWindow()
    private init() {}

    private var panel: NSPanel?
    private var dismissMonitor: Any?
    private var autoHideTask: Task<Void, Never>?
    private let size: CGFloat = 28

    /// 贴合选区显示图标：放在选区右端外侧、垂直居中。
    /// 选区矩形无效（退化为兜底点）时落在 fallback 鼠标点旁。
    func show(near selectionRect: NSRect, fallback: NSPoint, onTap: @escaping () -> Void) {
        // anchorRect 在拿不到 AX 边界时返回宽度≈1 的兜底矩形 → 用鼠标点
        let usable = selectionRect.width > 2 && selectionRect.height > 2
        let origin: NSPoint
        if usable {
            origin = NSPoint(x: selectionRect.maxX + 6, y: selectionRect.midY - size / 2)
        } else {
            origin = NSPoint(x: fallback.x + 6, y: fallback.y - size - 6)
        }
        show(atOrigin: origin, onTap: onTap)
    }

    /// 在某点附近显示图标；点击执行 onTap。
    func show(at point: NSPoint, onTap: @escaping () -> Void) {
        show(atOrigin: NSPoint(x: point.x + 6, y: point.y - size - 6), onTap: onTap)
    }

    private func show(atOrigin origin: NSPoint, onTap: @escaping () -> Void) {
        hide()

        var frame = NSRect(x: origin.x, y: origin.y, width: size, height: size)
        // 夹到选区所在屏幕内，避免落到屏幕外
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSPoint(x: origin.x, y: origin.y)) }) ?? NSScreen.main {
            let vf = screen.visibleFrame
            frame.origin.x = min(max(vf.minX + 4, frame.origin.x), vf.maxX - size - 4)
            frame.origin.y = min(max(vf.minY + 4, frame.origin.y), vf.maxY - size - 4)
        }
        let panel = NSPanel(contentRect: frame,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: SelectionIconView {
            onTap()
            Task { @MainActor in SelectionIconWindow.shared.hide() }
        })
        panel.orderFrontRegardless()
        self.panel = panel

        // 点击别处或一段时间后消失
        dismissMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
        autoHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self.hide()
        }
    }

    func hide() {
        autoHideTask?.cancel()
        autoHideTask = nil
        if let dismissMonitor { NSEvent.removeMonitor(dismissMonitor) }
        dismissMonitor = nil
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct SelectionIconView: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: BrandIcon.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.accentColor.opacity(hovering ? 1.0 : 0.9))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
