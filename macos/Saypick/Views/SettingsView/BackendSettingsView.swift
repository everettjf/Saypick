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
    @State private var installedModels: [String] = []
    @State private var isLoadingModels = false
    @State private var ollamaError: String?

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
                    HStack {
                        LabeledContent("Service", value: "\(OllamaConfig.host):\(OllamaConfig.port)")
                        Circle()
                            .fill(ollamaError == nil && !installedModels.isEmpty ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                            .accessibilityLabel(ollamaError == nil ? "Connected" : "Unavailable")
                    }

                    if isLoadingModels {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Checking Ollama…").foregroundStyle(.secondary)
                        }
                    } else if installedModels.isEmpty {
                        SettingsNote(
                            text: ollamaError ?? "No generation models are installed. Install one with `ollama pull qwen2.5:7b`.",
                            symbol: "exclamationmark.triangle.fill",
                            tint: .orange
                        )
                    } else {
                        Picker("Translation model", selection: $ollamaModel) {
                            ForEach(installedModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    HStack {
                        SettingsNote(text: "Embedding-only models are hidden because they cannot translate text.")
                        Spacer()
                        Button {
                            Task { await refreshModels() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .controlSize(.small)
                        .disabled(isLoadingModels)
                    }
                } header: {
                    SettingsSectionHeader(symbol: "desktopcomputer", color: .green,
                                          title: "Ollama", subtitle: "Local and private")
                }
            }
        }
        .settingsPage("Backend")
        .task(id: backendRaw) {
            if backendRaw == TranslationBackend.ollama.rawValue {
                await refreshModels()
            }
        }
    }

    @MainActor
    private func refreshModels() async {
        isLoadingModels = true
        ollamaError = nil
        defer { isLoadingModels = false }

        let allModels = await OllamaModelResolver.installedModels()
        installedModels = allModels.filter { model in
            let name = model.lowercased()
            return !name.contains("embed") && !name.contains("bge") && !name.contains("minilm")
        }

        guard !installedModels.isEmpty else {
            ollamaError = allModels.isEmpty
                ? "Ollama is not responding. Start Ollama, then refresh."
                : "Only embedding models are installed. Install a generation model to translate."
            return
        }

        if !installedModels.contains(ollamaModel), let first = installedModels.first {
            ollamaModel = first
        }
    }
}
