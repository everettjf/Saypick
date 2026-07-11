//
//  SkipAppsSettingsView.swift
//  Saypick
//
//  Created by eevv on 10/10/25.
//


import SwiftUI
import Ollama

struct SkipAppsSettingsView: View {
    @AppStorage("appSkipList") private var appSkipListString = ""
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
        VStack(alignment: .leading, spacing: 16) {
            // Header
            SettingsSectionHeader(symbol: "nosign", color: .red,
                                  title: "Skip Apps", subtitle: "Disable Saypick in these applications")
                .padding(.horizontal)
                .padding(.top)

            Divider()

            // Add new app
            HStack {
                TextField("Enter app name (e.g., Terminal, Xcode)", text: $newAppName)
                    .textFieldStyle(.roundedBorder)

                Button(action: addApp) {
                    Label("Add", systemImage: "plus")
                }
                .disabled(newAppName.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)

            // App list
            if !appSkipList.isEmpty {
                List {
                    ForEach(appSkipList, id: \.self) { app in
                        HStack {
                            Label(app, systemImage: "app.fill")
                                .foregroundColor(.primary)

                            Spacer()

                            Button(action: { removeApp(app) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.inset)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)

                    Text("Monitoring All Apps")
                        .font(.headline)

                    Text("No apps in skip list. Translation is active for all applications.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Spacer()
        }
        .navigationTitle("Skip Apps")
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