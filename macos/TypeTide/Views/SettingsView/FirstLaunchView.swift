import SwiftUI

struct FirstLaunchView: View {
    let openSection: (PreferencesSection) -> Void
    let finish: () -> Void

    @State private var hasPermission = AccessibilityPermission.isGranted
    @State private var backendResult: BackendHealthResult?
    @State private var isTestingBackend = false
    @State private var readStatus = TriggerController.shared.readShortcutStatus
    @State private var rewriteStatus = TriggerController.shared.rewriteShortcutStatus

    private var shortcutsReady: Bool { TriggerController.shared.shortcutsReady }
    private var backendReady: Bool { backendResult?.isSuccess == true }
    private var canFinish: Bool { hasPermission && backendReady && shortcutsReady }
    private var completedSteps: Int { [hasPermission, backendReady, shortcutsReady].filter { $0 }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Image("BrandMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 52, height: 52)
                        .accessibilityHidden(true)
                    Text("Welcome to TypeTide").font(.largeTitle.bold())
                    Text("Complete these checks once so global translation works reliably in every app.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    ProgressView(value: Double(completedSteps), total: 3)
                        .tint(TypeTideTheme.accent)
                    Text("\(completedSteps) of 3 complete")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                setupRow(
                    step: 1,
                    title: "Accessibility permission",
                    detail: hasPermission ? "Granted" : "Required to read and replace text in other apps.",
                    ready: hasPermission,
                    action: {
                        if hasPermission { recheck() }
                        else { AccessibilityPermission.requestAndOpenSystemSettings() }
                    },
                    actionLabel: hasPermission ? "Recheck" : "Grant Permission"
                )

                setupRow(
                    step: 2,
                    title: "Translation backend",
                    detail: backendResult?.message ?? "Test Ollama or your configured cloud endpoint with synthetic text.",
                    ready: backendReady,
                    action: { Task { await testBackend() } },
                    actionLabel: isTestingBackend ? "Testing…" : "Test Connection"
                )
                .disabled(isTestingBackend)

                setupRow(
                    step: 3,
                    title: "Global shortcuts",
                    detail: shortcutsReady
                        ? shortcutSummary
                        : "Set at least one shortcut; every shortcut you keep must be available and unique.",
                    ready: shortcutsReady,
                    action: {
                        TriggerController.shared.applyEnabledState()
                        recheck()
                    },
                    actionLabel: "Verify"
                )

                HStack {
                    Button("Configure Backend") { openSection(.backend) }
                    Button("Edit Shortcuts") { openSection(.shortcuts) }
                    Spacer()
                    Button("Finish Setup", action: finish)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canFinish)
                }

                SettingsNote(
                    text: "Diagnostics stay on this Mac and never include selected text, translations, clipboard contents, app names, endpoint URLs, or credentials.",
                    symbol: "hand.raised.fill",
                    tint: .green
                )
            }
            .padding(28)
            .frame(maxWidth: 680, alignment: .leading)
        }
        .navigationTitle("First Run")
        .onAppear { recheck() }
    }

    private func setupRow(
        step: Int,
        title: String,
        detail: String,
        ready: Bool,
        action: @escaping () -> Void,
        actionLabel: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(ready ? TypeTideTheme.success : TypeTideTheme.accentSoft)
                if ready {
                    Image(systemName: "checkmark").foregroundStyle(.white)
                } else {
                    Text("\(step)").font(.callout.bold()).foregroundStyle(TypeTideTheme.accent)
                }
            }
            .frame(width: 30, height: 30)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Button(actionLabel, action: action)
        }
        .padding(14)
        .background(.quaternary, in: .rect(cornerRadius: TypeTideTheme.Radius.card))
        .accessibilityElement(children: .contain)
    }

    private func recheck() {
        hasPermission = AccessibilityPermission.isGranted
        readStatus = TriggerController.shared.readShortcutStatus
        rewriteStatus = TriggerController.shared.rewriteShortcutStatus
    }

    private var shortcutSummary: String {
        let configured = [AppSettings.readShortcut, AppSettings.rewriteShortcut]
            .compactMap { $0?.displayString }
        return configured.count == 1
            ? "\(configured[0]) is registered. The other action is disabled."
            : "\(configured.joined(separator: " and ")) are registered."
    }

    @MainActor
    private func testBackend() async {
        isTestingBackend = true
        defer { isTestingBackend = false }
        backendResult = await BackendHealthChecker.check()
    }
}
