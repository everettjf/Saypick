//
//  BackendSettingsView.swift
//  Saypick
//
//  翻译后端设置：本地 Ollama / OpenAI 兼容。
//

import SwiftUI

struct BackendSettingsView: View {
    @AppStorage(AppSettings.Keys.backend) private var backendRaw = TranslationBackend.ollama.rawValue
    @AppStorage(AppSettings.Keys.openAIBaseURL) private var openAIBaseURL = "https://api.openai.com/v1"
    @AppStorage(AppSettings.Keys.openAIKey) private var openAIKey = ""
    @AppStorage(AppSettings.Keys.openAIModel) private var openAIModel = "gpt-4o-mini"
    @AppStorage(AppSettings.Keys.ollamaModel) private var ollamaModel = "qwen2.5:3b"

    var body: some View {
        Form {
            Section {
                Picker("Translation backend", selection: $backendRaw) {
                    ForEach(TranslationBackend.allCases) { backend in
                        Text(backend.displayName).tag(backend.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                SettingsSectionHeader(symbol: "server.rack", color: .teal,
                                      title: "Backend", subtitle: "Where translations are generated")
            }

            if backendRaw == TranslationBackend.openai.rawValue {
                Section {
                    TextField("Base URL", text: $openAIBaseURL)
                        .textFieldStyle(.roundedBorder)
                    SecureField("API Key", text: $openAIKey)
                        .textFieldStyle(.roundedBorder)
                    TextField("Model", text: $openAIModel)
                        .textFieldStyle(.roundedBorder)
                    SettingsNote(text: "Works with any OpenAI-compatible /chat/completions endpoint (official API, proxies, local servers).")
                } header: {
                    SettingsSectionHeader(symbol: "cloud.fill", color: .indigo, title: "OpenAI-compatible")
                }
            } else {
                Section {
                    LabeledContent("Host", value: "\(OllamaConfig.host):\(OllamaConfig.port)")
                    TextField("Model", text: $ollamaModel)
                        .textFieldStyle(.roundedBorder)
                    SettingsNote(text: "Browse and pull models in the Ollama Models tab.")
                } header: {
                    SettingsSectionHeader(symbol: "desktopcomputer", color: .green, title: "Ollama (local)")
                }
            }
        }
        .settingsPage("Backend")
    }
}
