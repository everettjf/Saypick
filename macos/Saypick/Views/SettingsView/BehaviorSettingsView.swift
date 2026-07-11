//
//  BehaviorSettingsView.swift
//  Saypick
//
//  触发与改写行为设置。
//

import SwiftUI

struct BehaviorSettingsView: View {
    @AppStorage(AppSettings.Keys.selectionTrigger) private var selectionRaw = SelectionTrigger.none.rawValue
    @AppStorage(AppSettings.Keys.rewritePreview) private var rewritePreview = false
    @AppStorage(AppSettings.Keys.rewriteStyle) private var rewriteStyleRaw = RewriteStyle.faithful.rawValue
    @AppStorage(AppSettings.Keys.readStyle) private var readStyleRaw = RewriteStyle.faithful.rawValue

    var body: some View {
        Form {
            Section {
                Picker("After selecting text", selection: $selectionRaw) {
                    ForEach(SelectionTrigger.allCases) { t in
                        Text(t.displayName).tag(t.rawValue)
                    }
                }
                .onChange(of: selectionRaw) { _, _ in
                    TriggerController.shared.applyEnabledState()
                }
                SettingsNote(text: "“Show floating icon” pops a small button next to your selection; “Auto-translate” shows the translation immediately. The shortcut always works regardless.")

                Picker("Style", selection: $readStyleRaw) {
                    ForEach(RewriteStyle.allCases) { s in
                        Text(s.displayName).tag(s.rawValue)
                    }
                }
            } header: {
                SettingsSectionHeader(symbol: "text.viewfinder", color: .blue,
                                      title: "Read · translate", subtitle: "How ⌥D is triggered and styled")
            }

            Section {
                Toggle(isOn: $rewritePreview) {
                    SettingsLabel(symbol: "eye.fill", color: .teal, title: "Preview before replacing")
                }
                SettingsNote(text: rewritePreview
                             ? "Rewrite shows the result in a popup; click Replace to apply."
                             : "Rewrite replaces the text in place immediately (undo with ⌘Z).")

                Picker("Style", selection: $rewriteStyleRaw) {
                    ForEach(RewriteStyle.allCases) { s in
                        Text(s.displayName).tag(s.rawValue)
                    }
                }
            } header: {
                SettingsSectionHeader(symbol: "pencil.and.outline", color: .purple,
                                      title: "Rewrite", subtitle: "How ⌥R applies the result")
            }
        }
        .settingsPage("Behavior")
    }
}
