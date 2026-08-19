//
//  BackendHealthChecker.swift
//  TypeTide
//

import Foundation

struct BackendHealthResult: Equatable {
    enum Status: Equatable {
        case success
        case failure
    }

    let status: Status
    let message: String
    let firstTokenMilliseconds: Int?
    let totalMilliseconds: Int

    var isSuccess: Bool { status == .success }
}

@MainActor
enum BackendHealthChecker {
    static func check() async -> BackendHealthResult {
        let start = ContinuousClock.now
        var firstToken: ContinuousClock.Instant?
        do {
            // Fixed synthetic text: health checks never use clipboard or selected content.
            for try await delta in TranslationService.shared.stream(
                text: "TypeTide health check",
                from: .english,
                to: .chinese,
                style: .faithful
            ) {
                if !delta.isEmpty, firstToken == nil { firstToken = .now }
            }
            let total = start.duration(to: .now).milliseconds
            let first = firstToken.map { start.duration(to: $0).milliseconds }
            let result = BackendHealthResult(
                status: .success,
                message: "Connected and translated successfully.",
                firstTokenMilliseconds: first,
                totalMilliseconds: total
            )
            record(result)
            return result
        } catch {
            let result = BackendHealthResult(
                status: .failure,
                message: userFacingMessage(for: error),
                firstTokenMilliseconds: firstToken.map { start.duration(to: $0).milliseconds },
                totalMilliseconds: start.duration(to: .now).milliseconds
            )
            record(result)
            return result
        }
    }

    private static func userFacingMessage(for error: Error) -> String {
        if let error = error as? TranslationError {
            return error.errorDescription ?? "The backend test failed."
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return "The backend timed out. Check the server and network connection."
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet:
                return AppSettings.backend == .ollama
                    ? "Can't reach Ollama. Start Ollama and verify 127.0.0.1:11434."
                    : "Can't reach the cloud endpoint. Check the Base URL and network connection."
            default:
                return urlError.localizedDescription
            }
        }
        return error.localizedDescription
    }

    private static func record(_ result: BackendHealthResult) {
        let event = DiagnosticEvent(
            name: .backendHealthCheck,
            outcome: result.isSuccess ? "success" : "failure",
            backend: AppSettings.backend.rawValue,
            errorCategory: result.isSuccess ? nil : "backend",
            firstTokenMilliseconds: result.firstTokenMilliseconds,
            totalMilliseconds: result.totalMilliseconds
        )
        Task { await LocalDiagnostics.shared.record(event) }
    }
}
