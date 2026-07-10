//
//  SaypickApp.swift
//  Saypick
//
//  纯菜单栏 App：MenuBarExtra + Settings 场景。
//

import SwiftUI
import AppKit
import TelemetryDeck
import Sentry

@main
struct SaypickApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            MenuBarIconLabel()
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
        }
    }
}

/// 菜单栏图标。顺带把 SwiftUI 的 openSettings 动作桥接给 AppKit 侧，
/// 供 AppDelegate 在“用户双击已运行的 App”等场景打开设置窗口。
private struct MenuBarIconLabel: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Image(systemName: BrandIcon.symbolName)
            .onAppear { SettingsOpener.handler = { openSettings() } }
    }
}

/// 从 AppKit 代码打开 SwiftUI Settings 场景的桥。
@MainActor
enum SettingsOpener {
    static var handler: (@MainActor () -> Void)?

    static func open() {
        NSApp.activate(ignoringOtherApps: true)
        if let handler {
            handler()
        } else {
            // 兜底：MenuBarExtra 场景尚未就绪时尝试旧的 AppKit 入口
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let firstLaunchKey = "hasCompletedFirstLaunch"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 纯菜单栏：不在 Dock 显示
        NSApp.setActivationPolicy(.accessory)

        // 监控/分析
        TelemetryDeck.initialize(config: .init(appID: "675A16AE-4E72-4AF8-A128-E1E416B5C3A0"))
        SentrySDK.start { options in
            options.dsn = "https://b872f0c33b8952a7f496ccea32dc623d@o4510180697636864.ingest.us.sentry.io/4510180700258304"
            options.debug = false
            options.sendDefaultPii = true
        }

        // 系统服务
        _ = SystemServiceProvider.shared

        // 注册全局快捷键 + 划词触发
        TriggerController.shared.start()

        // 若配置的 Ollama 模型未安装，自动挑一个已装模型（避免开箱即败）
        Task { @MainActor in
            await OllamaModelResolver.ensureValidDefault()
        }

        // 首次请求辅助功能权限
        if !AccessibilityPermission.isGranted {
            AccessibilityPermission.request()
        }

        // 首次启动：打开设置窗口，让用户立刻看到界面并完成配置
        if !UserDefaults.standard.bool(forKey: firstLaunchKey) {
            UserDefaults.standard.set(true, forKey: firstLaunchKey)
            Task { @MainActor in
                // 等 MenuBarExtra 场景装配完成，openSettings 桥才可用
                try? await Task.sleep(nanoseconds: 500_000_000)
                SettingsOpener.open()
            }
        }

        // 自动检查更新
        Task { @MainActor in
            if UpdateChecker.shared.shouldAutoCheck() {
                UpdateChecker.shared.checkForUpdates(silent: true)
            }
        }
    }

    /// App 已在运行时被再次打开（Finder/启动台双击）：没有可见窗口就打开设置，
    /// 避免“怎么双击都没反应”。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { SettingsOpener.open() }
        return true
    }
}
