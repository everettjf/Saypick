//
//  AboutView.swift
//  TypeTide
//
//  Created by eevv on 10/10/25.
//


import SwiftUI
import AppKit
import Ollama

struct AboutView: View {
    @StateObject private var updateChecker = UpdateChecker.shared
    @State private var showUpdateAlert = false

    // 动态获取应用版本信息
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App Icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)

            // App Name and Version
            VStack(spacing: 8) {
                Text("TypeTide")
                    .font(.largeTitle.weight(.bold))

                Text(appVersion)
                    .font(.title3)
                    .foregroundColor(.secondary)

                // 新版本提示
                if updateChecker.hasNewVersion, let release = updateChecker.latestRelease {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.green)
                        Text("New version \(release.tagName) available")
                            .font(.callout)
                            .foregroundColor(.green)
                    }
                    .padding(.top, 4)
                }
            }

            // Description
            VStack(spacing: 12) {
                Text("Intelligent Translation Assistant")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Select text to translate, or rewrite your own writing in place — in any app, powered by AI models")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)

            // 检查更新按钮
            VStack(spacing: 12) {
                Button(action: {
                    updateChecker.checkForUpdates(silent: false)
                    showUpdateAlert = true
                }) {
                    HStack {
                        if updateChecker.isChecking {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text(updateChecker.isChecking ? "Checking..." : "Check for Updates")
                    }
                    .frame(width: 180)
                }
                .buttonStyle(.bordered)
                .disabled(updateChecker.isChecking)

                // 如果有新版本，显示下载按钮
                if updateChecker.hasNewVersion {
                    Button(action: {
                        updateChecker.openReleasesPage()
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Download New Version")
                        }
                        .frame(width: 180)
                    }
                    .buttonStyle(.borderedProminent)
                }
                
//                Button {
//                    fatalError("Break the world")
//                } label: {
//                    Label("Break the world", systemImage: "figure.run")
//                }

            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("About")
        .alert("Update Check", isPresented: $showUpdateAlert, presenting: updateChecker) { checker in
            if checker.hasNewVersion {
                Button("Download") {
                    checker.openReleasesPage()
                }
                Button("Later", role: .cancel) {}
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: { checker in
            if checker.hasNewVersion, let release = checker.latestRelease {
                Text("New version \(release.tagName) is available!\n\nClick Download to open GitHub Releases page.")
            } else if let error = checker.errorMessage {
                Text("Failed to check for updates:\n\(error)")
            } else {
                Text("You're using the latest version!")
            }
        }
    }
}
