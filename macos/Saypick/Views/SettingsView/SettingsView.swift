//
//  SettingsView.swift
//  Saypick
//
//  设置页面 - 稳定的双栏布局，不让 NavigationSplitView 注入多余工具栏。
//

import SwiftUI

// MARK: - Main Settings Window

struct SettingsView: View {
    @State private var selection: PreferencesSection = .general

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 0) {
                List(PreferencesSection.allCases, selection: $selection) { section in
                    Label {
                        Text(section.rawValue)
                    } icon: {
                        IconBadge(symbol: section.icon, color: section.tint, size: 20)
                    }
                    .tag(section)
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 180, idealWidth: 190, maxWidth: 220)

            switch selection {
            case .general:
                GeneralSettingsView()
            case .behavior:
                BehaviorSettingsView()
            case .backend:
                BackendSettingsView()
            case .language:
                LanguageSettingsView()
            case .shortcuts:
                ShortcutsSettingsView()
            case .skipApps:
                SkipAppsSettingsView()
            case .about:
                AboutView()
            }
        }
        .frame(minWidth: 720, minHeight: 460)
    }
}

#Preview {
    SettingsView()
}
