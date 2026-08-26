//
//  SkipAppsSettingsView.swift
//  TypeTide
//
//  Created by eevv on 10/10/25.
//


import SwiftUI

struct SkipAppsSettingsView: View {
    @AppStorage(AppSettings.Keys.skipApps) private var appSkipListString = ""
    @State private var newAppName = ""

    var appSkipList: [String] {
        get {
            appSkipListString.split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set {
            appSkipListString = newValue.joined(separator: ",")
        }
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("App name, for example Terminal or Xcode", text: $newAppName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addApp)

                    Button(action: addApp) {
                        Label("Add", systemImage: "plus")
                    }
                    .disabled(newAppName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .buttonStyle(.borderedProminent)
                }
                SettingsNote(text: "Use the application name shown in the menu bar. TypeTide will ignore selections in matching apps.")
            } header: {
                SettingsSectionHeader(symbol: "plus.app.fill", color: .red,
                                      title: "Add an app", subtitle: "Disable TypeTide in sensitive or incompatible apps")
            }

            Section {
                if appSkipList.isEmpty {
                    SettingsEmptyState(
                        title: "Monitoring all apps",
                        message: "No exclusions are configured. TypeTide is active wherever selection capture is supported.",
                        symbol: "checkmark.shield.fill",
                        tint: TypeTideTheme.success
                    )
                } else {
                    ForEach(appSkipList, id: \.self) { app in
                        HStack {
                            Label(app, systemImage: "app.fill")
                            Spacer()
                            Button(role: .destructive, action: { removeApp(app) }) {
                                Label("Remove", systemImage: "trash")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.plain)
                            .help("Remove \(app)")
                        }
                    }
                }
            } header: {
                SettingsSectionHeader(symbol: "nosign", color: .red,
                                      title: "Excluded apps", subtitle: "\(appSkipList.count) configured")
            }
        }
        .settingsPage("Skip Apps")
    }

    private func addApp() {
        let trimmed = newAppName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !appSkipList.contains(trimmed) else { return }

        var current = appSkipList
        current.append(trimmed)
        appSkipListString = current.joined(separator: ",")
        newAppName = ""
    }

    private func removeApp(_ app: String) {
        var current = appSkipList
        current.removeAll { $0 == app }
        appSkipListString = current.joined(separator: ",")
    }
}
