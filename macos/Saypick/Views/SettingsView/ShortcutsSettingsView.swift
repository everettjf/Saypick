//
//  ShortcutsSettingsView.swift
//  Saypick
//
//  快捷键设置：读·划词翻译 / 写·输入改写。
//

import SwiftUI
import AppKit

struct ShortcutsSettingsView: View {
    @State private var readShortcut = AppSettings.readShortcut
    @State private var rewriteShortcut = AppSettings.rewriteShortcut

    var body: some View {
        Form {
            Section {
                ShortcutRecorderRow(icon: "text.magnifyingglass", color: .blue,
                                    title: "Translate selection", shortcut: $readShortcut) { new in
                    AppSettings.readShortcut = new
                    TriggerController.shared.applyEnabledState()
                }
                ShortcutRecorderRow(icon: "arrow.left.arrow.right", color: .green,
                                    title: "Rewrite & replace", shortcut: $rewriteShortcut) { new in
                    AppSettings.rewriteShortcut = new
                    TriggerController.shared.applyEnabledState()
                }
            } header: {
                SettingsSectionHeader(symbol: "keyboard.fill", color: .pink,
                                      title: "Shortcuts", subtitle: "Global · work in any app")
            }
        }
        .settingsPage("Shortcuts")
    }
}

private struct ShortcutRecorderRow: View {
    let icon: String
    var color: Color = .blue
    let title: String
    @Binding var shortcut: KeyboardShortcutPreference
    let onChange: (KeyboardShortcutPreference) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            SettingsLabel(symbol: icon, color: color, title: title)
            Spacer()
            Button {
                isRecording ? stop() : start()
            } label: {
                Group {
                    if isRecording {
                        Text("Press keys…").foregroundColor(.secondary)
                    } else {
                        Text(shortcut.displayString).font(.system(.body, design: .monospaced))
                    }
                }
                .frame(minWidth: 90)
            }
            .buttonStyle(.bordered)
        }
        .onDisappear { stop() }
    }

    private func start() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            let mods = event.modifierFlags.toShortcutModifiers()
            if !mods.isEmpty {
                let s = KeyboardShortcutPreference(keyCode: Int(event.keyCode), modifiers: mods)
                shortcut = s
                onChange(s)
                stop()
                return nil
            }
            return event
        }
    }

    private func stop() {
        isRecording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

private extension NSEvent.ModifierFlags {
    func toShortcutModifiers() -> KeyboardShortcutPreference.ModifierFlags {
        var flags = KeyboardShortcutPreference.ModifierFlags()
        if contains(.command) { flags.insert(.command) }
        if contains(.option) { flags.insert(.option) }
        if contains(.control) { flags.insert(.control) }
        if contains(.shift) { flags.insert(.shift) }
        return flags
    }
}
