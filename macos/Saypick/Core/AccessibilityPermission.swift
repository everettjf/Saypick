//
//  AccessibilityPermission.swift
//  Saypick
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

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
