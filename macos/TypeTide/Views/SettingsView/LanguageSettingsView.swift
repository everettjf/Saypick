//
//  LanguageSettingsView.swift
//  TypeTide
//
//  Created by eevv on 10/10/25.
//


import SwiftUI

struct LanguageSettingsView: View {
    @State private var selectedLanguage = LanguageConfig.sourceLanguage
    @State private var selectedTargetLanguage = LanguageConfig.targetLanguage
    @State private var readDirection = AppSettings.readDirection
    @State private var rewriteDirection = AppSettings.rewriteDirection

    var body: some View {
        Form {
            Section {
                Picker("Native language", selection: $selectedLanguage) {
                    ForEach(Language.allCases) { language in
                        Text(language.displayName)
                            .tag(language)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedLanguage) { _, newLanguage in
                    LanguageConfig.sourceLanguage = newLanguage
                }

                Picker("Foreign language", selection: $selectedTargetLanguage) {
                    ForEach(Language.allCases) { language in
                        Text(language.displayName)
                            .tag(language)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedTargetLanguage) { _, newLanguage in
                    LanguageConfig.targetLanguage = newLanguage
                }

                if selectedLanguage == selectedTargetLanguage {
                    HStack(alignment: .top, spacing: 10) {
                        IconBadge(symbol: "exclamationmark.triangle.fill", color: .red, size: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Same language selected")
                                .font(.callout.weight(.semibold))
                                .foregroundColor(.red)
                            Text("Native and foreign are both \(selectedLanguage.shortName). Translation won't do anything useful.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    SettingsNote(text: "TypeTide translates between \(selectedLanguage.shortName) and \(selectedTargetLanguage.shortName). Make sure your AI model supports both.")
                }
            } header: {
                SettingsSectionHeader(symbol: "globe", color: .green,
                                      title: "Languages", subtitle: "Your native + foreign pair")
            }

            Section {
                Picker("⌥D Read (popup)", selection: $readDirection) {
                    ForEach(TranslationDirection.allCases) { dir in
                        Text(dir.label(native: selectedLanguage, foreign: selectedTargetLanguage))
                            .tag(dir)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: readDirection) { _, newValue in
                    AppSettings.readDirection = newValue
                }

                Picker("⌥R Rewrite (replace in place)", selection: $rewriteDirection) {
                    ForEach(TranslationDirection.allCases) { dir in
                        Text(dir.label(native: selectedLanguage, foreign: selectedTargetLanguage))
                            .tag(dir)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: rewriteDirection) { _, newValue in
                    AppSettings.rewriteDirection = newValue
                }

                SettingsNote(text: "Auto detects the selected text's language and translates to the other one. Choose a fixed direction if you only ever translate one way, or if mixed-language text gets mis-detected.")
            } header: {
                SettingsSectionHeader(symbol: "arrow.left.arrow.right.circle.fill", color: .orange,
                                      title: "Translation Direction", subtitle: "Per shortcut · auto or fixed")
            }

        }
        .settingsPage("Language")
    }
}
