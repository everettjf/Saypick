//
//  GeneralSettingsView.swift
//  Saypick
//

import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(AppSettings.Keys.enabled) private var isEnabled = true
    @State private var hasPermission = AccessibilityPermission.isGranted
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var permissionTimer: Timer?

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $isEnabled) {
                    SettingsLabel(symbol: "power", color: .green, title: "Enable Saypick")
                }
                .onChange(of: isEnabled) { _, _ in
                    TriggerController.shared.applyEnabledState()
                }

                Toggle(isOn: $launchAtLogin) {
                    SettingsLabel(symbol: "arrow.up.forward.app.fill", color: .indigo, title: "Launch at login")
                }
                .onChange(of: launchAtLogin) { _, newValue in
                    if !LaunchAtLogin.set(newValue) {
                        // 失败时回滚到真实状态
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                }

                HStack {
                    SettingsLabel(symbol: hasPermission ? "checkmark.shield.fill" : "exclamationmark.shield.fill",
                                  color: hasPermission ? .blue : .orange,
                                  title: "Accessibility Permission")
                    Spacer()
                    if hasPermission {
                        Text("Granted").foregroundColor(.blue).fontWeight(.medium)
                    } else {
                        Button("Grant Permission") { AccessibilityPermission.request() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }

                if !hasPermission {
                    VStack(alignment: .leading, spacing: 8) {
                        SettingsNote(text: "Saypick needs Accessibility permission to read selected text and replace text in other apps.",
                                     symbol: "exclamationmark.triangle.fill", tint: .orange)
                        Button("Open System Settings") { AccessibilityPermission.openSystemSettings() }
                            .controlSize(.small)
                    }
                }
            } header: {
                SettingsSectionHeader(symbol: "gearshape.fill", color: .blue,
                                      title: "Status", subtitle: "Core toggles and permissions")
            }

            Section {
                SettingsLabel(symbol: "text.magnifyingglass", color: .blue,
                              title: "Select text, then press \(AppSettings.readShortcut.displayString) to see the translation.")
                SettingsLabel(symbol: "arrow.left.arrow.right", color: .green,
                              title: "Type in your language, then press \(AppSettings.rewriteShortcut.displayString) to replace it with the translation.")
            } header: {
                SettingsSectionHeader(symbol: "book.fill", color: .purple, title: "How to use")
            }
        }
        .settingsPage("General")
        .onAppear {
            hasPermission = AccessibilityPermission.isGranted
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                Task { @MainActor in hasPermission = AccessibilityPermission.isGranted }
            }
        }
        .onDisappear {
            permissionTimer?.invalidate()
            permissionTimer = nil
        }
    }
}
