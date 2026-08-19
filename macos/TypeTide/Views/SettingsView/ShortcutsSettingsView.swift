//
//  ShortcutsSettingsView.swift
//  TypeTide
//
//  快捷键设置：读·划词翻译 / 写·输入改写。
//

import SwiftUI
import AppKit

struct ShortcutsSettingsView: View {
    @State private var readShortcut = AppSettings.readShortcut
    @State private var rewriteShortcut = AppSettings.rewriteShortcut
    @State private var readStatus = TriggerController.shared.readShortcutStatus
    @State private var rewriteStatus = TriggerController.shared.rewriteShortcutStatus
    @State private var validationMessage: String?
    @State private var readAction = AppSettings.readShortcutAction
    @State private var rewriteAction = AppSettings.rewriteShortcutAction

    var body: some View {
        Form {
            Section {
                ShortcutRecorderRow(icon: "text.magnifyingglass", color: .blue,
                                    title: "Translate selection", shortcut: $readShortcut,
                                    status: readStatus) { new in
                    apply(new, forRead: true)
                }
                Picker("Translate shortcut action", selection: $readAction) {
                    ForEach(ShortcutAction.allCases) { action in
                        Text(action.displayName).tag(action)
                    }
                }
                .onChange(of: readAction) { _, value in AppSettings.readShortcutAction = value }
                ShortcutRecorderRow(icon: "arrow.left.arrow.right", color: .green,
                                    title: "Rewrite & replace", shortcut: $rewriteShortcut,
                                    status: rewriteStatus) { new in
                    apply(new, forRead: false)
                }
                Picker("Rewrite shortcut action", selection: $rewriteAction) {
                    ForEach(ShortcutAction.allCases) { action in
                        Text(action.displayName).tag(action)
                    }
                }
                .onChange(of: rewriteAction) { _, value in AppSettings.rewriteShortcutAction = value }
                if let validationMessage {
                    SettingsNote(text: validationMessage, symbol: "exclamationmark.triangle.fill", tint: .orange)
                }
                HStack {
                    Button("Restore Defaults") { restoreDefaults() }
                    Spacer()
                    Button {
                        verifyRegistration()
                    } label: {
                        Label("Verify Shortcuts", systemImage: "checkmark.circle")
                    }
                }
            } header: {
                SettingsSectionHeader(symbol: "keyboard.fill", color: .pink,
                                      title: "Shortcuts", subtitle: "Global · work in any app")
            }
        }
        .settingsPage("Shortcuts")
        .onAppear { verifyRegistration() }
    }

    private func apply(_ shortcut: KeyboardShortcutPreference?, forRead: Bool) {
        let other = forRead ? rewriteShortcut : readShortcut
        guard shortcut == nil || other == nil || shortcut != other else {
            validationMessage = "Translate and rewrite must use different shortcuts. The previous shortcut was kept."
            if forRead { readShortcut = AppSettings.readShortcut }
            else { rewriteShortcut = AppSettings.rewriteShortcut }
            return
        }
        validationMessage = shortcut.flatMap(riskyShortcutMessage)
        if forRead { readShortcut = shortcut }
        else { rewriteShortcut = shortcut }
        if forRead { AppSettings.readShortcut = shortcut }
        else { AppSettings.rewriteShortcut = shortcut }
        verifyRegistration()
    }

    private func verifyRegistration() {
        TriggerController.shared.applyEnabledState()
        readStatus = TriggerController.shared.readShortcutStatus
        rewriteStatus = TriggerController.shared.rewriteShortcutStatus
        if readShortcut == nil && rewriteShortcut == nil {
            validationMessage = "Set at least one shortcut so TypeTide can be triggered from the keyboard."
        } else if !TriggerController.shared.shortcutsReady {
            validationMessage = "One or more shortcuts could not be registered. Choose a different combination."
        } else if validationMessage?.contains("could not be registered") == true
                    || validationMessage?.contains("at least one shortcut") == true {
            validationMessage = nil
        }
    }

    private func restoreDefaults() {
        readShortcut = AppSettings.defaultReadShortcut
        rewriteShortcut = AppSettings.defaultRewriteShortcut
        AppSettings.readShortcut = readShortcut
        AppSettings.rewriteShortcut = rewriteShortcut
        validationMessage = nil
        verifyRegistration()
    }

    private func riskyShortcutMessage(_ shortcut: KeyboardShortcutPreference) -> String? {
        let commandOnly = shortcut.modifiers == [.command]
        let key = KeyCodeMapper.string(for: shortcut.keyCode)
        if commandOnly, ["C", "V", "X", "A", "Z", "Q", "W"].contains(key ?? "") {
            return "This combination is commonly used by macOS and may interfere with normal editing."
        }
        return nil
    }
}

private struct ShortcutRecorderRow: View {
    let icon: String
    var color: Color = .blue
    let title: String
    @Binding var shortcut: KeyboardShortcutPreference?
    let status: ShortcutRegistrationStatus
    let onChange: (KeyboardShortcutPreference?) -> Void

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
                        Text("Press keys…").foregroundStyle(.secondary)
                    } else {
                        Text(shortcut?.displayString ?? "Not set")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(shortcut == nil ? Color.gray : Color.primary)
                    }
                }
                .frame(minWidth: 90)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(shortcut == nil ? "Set \(title) shortcut" : "Change \(title) shortcut")
            if shortcut != nil {
                Button {
                    clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear shortcut")
                .accessibilityLabel("Clear \(title) shortcut")
            }
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .help(status.message)
                .accessibilityLabel(status.message)
        }
        .onDisappear { stop() }
    }

    private func start() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 53 { // Escape cancels recording.
                stop()
                return nil
            }
            if event.keyCode == 51 || event.keyCode == 117 { // Delete / Forward Delete clears.
                clear()
                return nil
            }
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

    private func clear() {
        shortcut = nil
        onChange(nil)
        stop()
    }

    private var statusIcon: String {
        switch status {
        case .registered: return "checkmark.circle.fill"
        case .notConfigured: return "minus.circle.fill"
        case .inactive, .duplicate, .unavailable: return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch status {
        case .registered: return .green
        case .notConfigured: return .gray
        case .inactive, .duplicate, .unavailable: return .orange
        }
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
