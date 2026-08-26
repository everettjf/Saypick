import SwiftUI
import UniformTypeIdentifiers

struct DiagnosticsSettingsView: View {
    @State private var events: [DiagnosticEvent] = []
    @State private var exportDocument = DiagnosticsDocument(data: Data())
    @State private var isExporting = false
    private let metricColumns = [GridItem(.adaptive(minimum: 132), spacing: TypeTideTheme.Spacing.medium)]

    private var translations: [DiagnosticEvent] { events.filter { $0.name == .translation } }
    private var captureSuccesses: Int {
        events.filter { $0.name == .selectionCapture && $0.outcome == "success" }.count
    }
    private var replacementSuccesses: Int {
        events.filter { $0.name == .replacement && $0.outcome == "success" }.count
    }
    private var averageFirstToken: Int? {
        let values = translations.compactMap(\.firstTokenMilliseconds)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / values.count
    }

    var body: some View {
        Form {
            Section {
                LazyVGrid(columns: metricColumns, alignment: .leading, spacing: TypeTideTheme.Spacing.medium) {
                    metricCard("Captures", value: "\(captureSuccesses)", symbol: "text.magnifyingglass")
                    metricCard("Replacements", value: "\(replacementSuccesses)", symbol: "arrow.left.arrow.right")
                    metricCard("Translations", value: "\(translations.count)", symbol: "character.book.closed")
                    metricCard("Avg. first token", value: averageFirstToken.map { "\($0) ms" } ?? "—", symbol: "bolt.fill")
                }
            } header: {
                SettingsSectionHeader(symbol: "waveform.path.ecg", color: .purple,
                                      title: "Local Diagnostics", subtitle: "Up to 500 recent operational events")
            }

            Section {
                SettingsNote(
                    text: "Stored only on this Mac. TypeTide never records selected text, translations, clipboard contents, app names, endpoint URLs, or credentials.",
                    symbol: "lock.shield.fill",
                    tint: .green
                )
                HStack {
                    Button {
                        Task { await prepareExport() }
                    } label: {
                        Label("Export Report…", systemImage: "square.and.arrow.up")
                    }
                    Spacer()
                    Button("Clear Diagnostics", role: .destructive) {
                        Task {
                            await LocalDiagnostics.shared.removeAll()
                            await reload()
                        }
                    }
                    .disabled(events.isEmpty)
                }
            } header: {
                SettingsSectionHeader(symbol: "hand.raised.fill", color: .green, title: "Privacy & Control")
            }

            Section {
                if events.isEmpty {
                    ContentUnavailableView("No diagnostics yet", systemImage: "waveform.path.ecg",
                                           description: Text("Use TypeTide or run a backend test to create local events."))
                } else {
                    ForEach(events.suffix(12).reversed()) { event in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.name.rawValue).font(.callout.weight(.medium))
                                Text(event.timestamp, style: .time).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(event.outcome)
                                .foregroundStyle(event.outcome == "failure" ? .orange : .secondary)
                            if let total = event.totalMilliseconds {
                                Text("\(total) ms").monospacedDigit().foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                SettingsSectionHeader(symbol: "clock.arrow.circlepath", color: .blue, title: "Recent Events")
            }
        }
        .settingsPage("Diagnostics")
        .task { await reload() }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "TypeTide-Diagnostics"
        ) { _ in }
    }

    private func metricCard(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold()).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary, in: .rect(cornerRadius: 9))
    }

    @MainActor
    private func reload() async {
        events = await LocalDiagnostics.shared.events()
    }

    @MainActor
    private func prepareExport() async {
        guard let data = try? await LocalDiagnostics.shared.exportData() else { return }
        exportDocument = DiagnosticsDocument(data: data)
        isExporting = true
    }
}

struct DiagnosticsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
