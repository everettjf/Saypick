//
//  ModelsSettingsView.swift
//  Saypick
//
//  Created by eevv on 10/10/25.
//


import SwiftUI
import Ollama

struct ModelsSettingsView: View {
    @AppStorage("selectedModel") private var selectedModel = "qwen2.5:3b"
    @State private var availableModels: [Ollama.Client.ListModelsResponse.Model] = []
    @State private var isLoadingModels = false
    @State private var modelLoadError: String?
    @State private var isPullingModel = false
    @State private var pullStatusMessage: String?
    @State private var pullStatusIsError = false
    @State private var currentPullModelName: String?

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    private let recommendedStarterModel = "qwen2.5:3b"

    var body: some View {
        let hasLocalModels = !availableModels.isEmpty

        Form {
            Section {
                if isLoadingModels {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Loading models…")
                    }
                    .padding(.vertical, 4)
                } else if let modelLoadError {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Unable to load models", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(modelLoadError)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button {
                            Task { await refreshModels(force: true) }
                        } label: {
                            Label("Retry", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isLoadingModels || isPullingModel)
                    }
                } else if availableModels.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No local models detected")
                            .font(.callout.weight(.medium))
                        Text("Run `ollama pull <model>` to install a model, then refresh.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Download \(recommendedStarterModel) to get started quickly.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button {
                            Task { await refreshModels(force: true) }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isLoadingModels || isPullingModel)

                        if !availableModels.contains(where: { $0.name == recommendedStarterModel }) {
                            Button {
                                Task { await pullModel(named: recommendedStarterModel) }
                            } label: {
                                Label("Download \(recommendedStarterModel)", systemImage: "arrow.down.circle")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(isLoadingModels || isPullingModel)
                        }
                    }
                } else {
                    Picker("Default model", selection: $selectedModel) {
                        ForEach(availableModels, id: \.name) { model in
                            Text(displayName(for: model))
                                .tag(model.name)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()

                    HStack(spacing: 12) {
                        Button {
                            Task { await refreshModels(force: true) }
                        } label: {
                            Label("Refresh Models", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isLoadingModels || isPullingModel)

                        if !availableModels.contains(where: { $0.name == selectedModel }) {
                            Button {
                                Task { await pullModel(named: selectedModel) }
                            } label: {
                                Label("Download \(selectedModel)", systemImage: "arrow.down.circle")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(isLoadingModels || isPullingModel)
                        }
                    }
                }
            } header: {
                SettingsSectionHeader(symbol: "cpu", color: .orange,
                                      title: "Available Models", subtitle: "The model used for translate & rewrite")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: hasLocalModels ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(hasLocalModels ? .green : .orange)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(hasLocalModels ? "Ollama Installed" : "Ollama Required")
                                .font(.callout.weight(.medium))
                            Text("Make sure Ollama is running and the selected model is installed. Ollama runs the local models used for translation.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Link(destination: URL(string: "https://ollama.com")!) {
                                Text("https://ollama.com")
                            }
                            if isPullingModel {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text("Downloading \(currentPullModelName ?? "model")…")
                                        .font(.caption.weight(.medium))
                                }
                            } else if let pullStatusMessage {
                                Text(pullStatusMessage)
                                    .font(.caption)
                                    .foregroundColor(pullStatusIsError ? .red : .green)
                            }
                        }
                    }

                }
            } header: {
                SettingsSectionHeader(symbol: "shippingbox.fill", color: .indigo, title: "Ollama Setup")
            }
        }
        .settingsPage("Models")
        .task {
            await refreshModels()
        }
    }

    @MainActor
    private func refreshModels(force: Bool = false) async {
        if isLoadingModels && !force {
            return
        }

        isLoadingModels = true
        modelLoadError = nil

        defer { isLoadingModels = false }

        do {
            guard let hostURL = URL(string: "\(OllamaConfig.host):\(OllamaConfig.port)") else {
                modelLoadError = "Invalid Ollama host configuration."
                return
            }

            let client = Ollama.Client(host: hostURL)
            let response = try await client.listModels()
            // 保持 Ollama 返回的原始顺序，不进行排序
            availableModels = response.models

            if let firstModel = response.models.first,
               response.models.contains(where: { $0.name == selectedModel }) == false {
                selectedModel = firstModel.name
            }

            modelLoadError = nil
        } catch {
            if let clientError = error as? Ollama.Client.Error {
                modelLoadError = clientError.description
            } else {
                modelLoadError = error.localizedDescription
            }
            print("⚠️ Failed to fetch models: \(error)")
        }
    }

    @MainActor
    private func pullModel(named name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isPullingModel else { return }

        guard let hostURL = URL(string: "\(OllamaConfig.host):\(OllamaConfig.port)") else {
            pullStatusMessage = "Invalid Ollama host configuration."
            pullStatusIsError = true
            return
        }

        guard let modelID = Ollama.Model.ID(rawValue: trimmed) else {
            pullStatusMessage = "Invalid model identifier: \(trimmed)."
            pullStatusIsError = true
            return
        }

        isPullingModel = true
        currentPullModelName = trimmed
        pullStatusMessage = "Downloading \(trimmed)…"
        pullStatusIsError = false
        modelLoadError = nil

        defer {
            isPullingModel = false
            currentPullModelName = nil
        }

        do {
            let client = Ollama.Client(host: hostURL)
            let success = try await client.pullModel(modelID)

            if success {
                await refreshModels(force: true)
                if availableModels.contains(where: { $0.name == trimmed }) {
                    selectedModel = trimmed
                }
                pullStatusMessage = "Model \(trimmed) downloaded successfully."
                pullStatusIsError = false
            } else {
                pullStatusMessage = "Failed to download \(trimmed)."
                pullStatusIsError = true
            }
        } catch {
            let message: String
            if let clientError = error as? Ollama.Client.Error {
                message = clientError.description
            } else {
                message = error.localizedDescription
            }
            pullStatusMessage = message
            pullStatusIsError = true
            print("⚠️ Failed to pull model \(trimmed): \(error)")
        }
    }

    private func displayName(for model: Ollama.Client.ListModelsResponse.Model) -> String {
        var components: [String] = []

        components.append(model.name)

        let sizeString = Self.byteFormatter.string(fromByteCount: model.size)
        components.append(sizeString)

        if let date = Self.isoFormatter.date(from: model.modifiedAt) {
            let relativeDate = Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
            components.append(relativeDate)
        }

        return components.joined(separator: " • ")
    }
}