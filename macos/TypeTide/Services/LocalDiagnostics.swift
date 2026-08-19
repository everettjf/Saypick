//
//  LocalDiagnostics.swift
//  TypeTide
//
//  Local-only operational diagnostics. Events deliberately contain no source text,
//  translated text, clipboard contents, application names, URLs, or API keys.
//

import Foundation

enum DiagnosticEventName: String, Codable {
    case selectionCapture
    case translation
    case replacement
    case shortcutRegistration
    case backendHealthCheck
}

struct DiagnosticEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let name: DiagnosticEventName
    let outcome: String
    let platform: String
    let backend: String?
    let captureMethod: String?
    let errorCategory: String?
    let firstTokenMilliseconds: Int?
    let totalMilliseconds: Int?
    let inputCharacterCount: Int?

    init(
        name: DiagnosticEventName,
        outcome: String,
        backend: String? = nil,
        captureMethod: String? = nil,
        errorCategory: String? = nil,
        firstTokenMilliseconds: Int? = nil,
        totalMilliseconds: Int? = nil,
        inputCharacterCount: Int? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.name = name
        self.outcome = outcome
        self.platform = "macOS"
        self.backend = backend
        self.captureMethod = captureMethod
        self.errorCategory = errorCategory
        self.firstTokenMilliseconds = firstTokenMilliseconds
        self.totalMilliseconds = totalMilliseconds
        self.inputCharacterCount = inputCharacterCount
    }
}

actor LocalDiagnostics {
    static let shared = LocalDiagnostics()

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let maximumEvents = 500

    init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func record(_ event: DiagnosticEvent) {
        var events = loadEvents()
        events.append(event)
        if events.count > maximumEvents {
            events.removeFirst(events.count - maximumEvents)
        }
        save(events)
    }

    func events() -> [DiagnosticEvent] {
        loadEvents()
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: Self.fileURL)
    }

    func exportData() throws -> Data {
        let report = DiagnosticReport(
            generatedAt: Date(),
            privacyNotice: "Contains operational metadata only. No selected text, translations, clipboard contents, application names, URLs, or credentials are recorded.",
            events: loadEvents()
        )
        return try encoder.encode(report)
    }

    private func loadEvents() -> [DiagnosticEvent] {
        guard let data = try? Data(contentsOf: Self.fileURL),
              let events = try? decoder.decode([DiagnosticEvent].self, from: data) else {
            return []
        }
        return events
    }

    private func save(_ events: [DiagnosticEvent]) {
        do {
            let directory = Self.fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try encoder.encode(events)
            try data.write(to: Self.fileURL, options: .atomic)
        } catch {
            // Diagnostics must never interfere with translation.
        }
    }

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("TypeTide", isDirectory: true)
            .appendingPathComponent("diagnostics.json")
    }
}

private nonisolated struct DiagnosticReport: Codable {
    let generatedAt: Date
    let privacyNotice: String
    let events: [DiagnosticEvent]
}
