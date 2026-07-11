//
//  SettingsView.swift
//  Saypick
//
//  设置页面 - 使用 NavigationSplitView 架构
//

import SwiftUI

// MARK: - Main Settings Window

struct SettingsView: View {
    @State private var selection: PreferencesSection? = .general

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(PreferencesSection.allCases, selection: $selection) { section in
                Label {
                    Text(section.rawValue)
                } icon: {
                    IconBadge(symbol: section.icon, color: section.tint, size: 20)
                }
                .tag(section)
            }
            .listStyle(.sidebar)
            .navigationTitle("Saypick")
            .frame(minWidth: 190)
        } detail: {
            // Detail content
            switch selection {
            case .general:
                GeneralSettingsView()
            case .behavior:
                BehaviorSettingsView()
            case .backend:
                BackendSettingsView()
            case .language:
                LanguageSettingsView()
            case .models:
                ModelsSettingsView()
            case .shortcuts:
                ShortcutsSettingsView()
            case .skipApps:
                SkipAppsSettingsView()
            case .about:
                AboutView()
            case .none:
                Text("Select a section from the sidebar")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}

#Preview {
    SettingsView()
}
