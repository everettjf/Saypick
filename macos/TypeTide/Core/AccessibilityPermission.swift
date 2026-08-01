//
//  AccessibilityPermission.swift
//  TypeTide
//
//  辅助功能权限助手。
//

import ApplicationServices
import AppKit

enum AccessibilityPermission {
    static var isGranted: Bool { AXIsProcessTrusted() }

    /// 请求权限（首次会弹出系统提示）。
    static func request() {
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// 先让 TCC 登记当前签名应用，再打开对应设置页供用户亲自开启开关。
    /// macOS 出于安全原因不允许应用替用户授予或启用这项权限。
    @MainActor
    static func requestAndOpenSystemSettings() {
        request()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            openSystemSettings()
        }
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
