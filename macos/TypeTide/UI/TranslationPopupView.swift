//
//  TranslationPopupView.swift
//  TypeTide
//
//  划词翻译弹窗内容（流式展示）。
//

import SwiftUI
import AppKit
import Combine

@MainActor
final class TranslationPopupModel: ObservableObject {
    enum TidePhase: Equatable {
        case waiting
        case flowing
        case settling
        case complete
        case failed
    }

    @Published var original: String
    @Published var translation: String = ""
    @Published var isLoading: Bool = true
    @Published var errorText: String?
    @Published private(set) var tidePhase: TidePhase = .waiting
    /// 当前目标语言（弹窗顶部可改选，触发 onRetarget 重新翻译）
    @Published var targetLanguage: Language

    /// 复制译文
    var onCopy: (() -> Void)?
    /// 替换原文（读模式可选；为 nil 时不显示）
    var onReplace: (() -> Void)?
    /// 用户在弹窗里改选目标语言时回调（按新目标重新翻译）
    var onRetarget: ((Language) -> Void)?
    /// 翻译失败后重试当前请求
    var onRetry: (() -> Void)?
    /// 弹窗关闭时取消仍在进行的请求
    var onDismiss: (() -> Void)?

    init(original: String, target: Language) {
        self.original = original
        self.targetLanguage = target
    }

    func resetTranslation() {
        translation = ""
        isLoading = true
        errorText = nil
        tidePhase = .waiting
    }

    func appendTranslation(_ delta: String) {
        guard !delta.isEmpty else { return }
        translation += delta
        isLoading = false
        tidePhase = .flowing
    }

    func finishTranslation() {
        isLoading = false
        tidePhase = translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? .failed : .settling
    }

    func finishTide() {
        if tidePhase == .settling { tidePhase = .complete }
    }

    func failTranslation(_ message: String) {
        isLoading = false
        errorText = message
        tidePhase = .failed
    }
}

struct TranslationPopupView: View {
    @ObservedObject var model: TranslationPopupModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: TypeTideTheme.Control.popupWidth)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(.rect(cornerRadius: TypeTideTheme.Radius.popup))
        .overlay(
            RoundedRectangle(cornerRadius: TypeTideTheme.Radius.popup)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 6)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(nsImage: BrandIcon.templateImage)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(TypeTideTheme.accent)
            Text("TypeTide")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            targetMenu
            Button {
                PopupController.shared.close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: TypeTideTheme.Control.minimumHitSize,
                           height: TypeTideTheme.Control.minimumHitSize)
            }
            .buttonStyle(.plain)
            .help("Close")
            .accessibilityLabel("Close translation")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    /// 目标语言下拉：即时把当前译文重定向到任意语言（含第三种语言）
    private var targetMenu: some View {
        Menu {
            ForEach(Language.allCases) { lang in
                Button {
                    guard lang != model.targetLanguage else { return }
                    model.onRetarget?(lang)
                } label: {
                    if lang == model.targetLanguage {
                        Label(lang.displayName, systemImage: "checkmark")
                    } else {
                        Text(lang.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "globe")
                    .font(.system(size: 10))
                Text(model.targetLanguage.shortName)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, TypeTideTheme.Spacing.xSmall)
            .frame(minHeight: TypeTideTheme.Control.compactHeight)
            .background(.quaternary.opacity(0.55), in: .rect(cornerRadius: TypeTideTheme.Radius.control))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let err = model.errorText {
                VStack(alignment: .leading, spacing: 10) {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(TypeTideTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                    if model.onRetry != nil {
                        HStack {
                            Spacer()
                            Button {
                                model.onRetry?()
                            } label: {
                                Label("Retry", systemImage: "arrow.clockwise")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
            } else {
                ScrollView {
                    TideTranslationText(model: model, reduceMotion: reduceMotion)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 260)
            }

            if !model.translation.isEmpty && model.errorText == nil {
                HStack(spacing: 10) {
                    Spacer()
                    Button {
                        model.onCopy?()
                        copied = true
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(1.2))
                            copied = false
                        }
                    } label: {
                        Label(copied ? "Copied" : "Copy",
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityHint("Copies the complete translation to the clipboard")

                    if model.onReplace != nil {
                        Button {
                            model.onReplace?()
                        } label: {
                            Label("Replace", systemImage: "arrow.left.arrow.right")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TideTranslationText: View {
    @ObservedObject var model: TranslationPopupModel
    let reduceMotion: Bool

    private var isMoving: Bool {
        switch model.tidePhase {
        case .waiting, .flowing, .settling: true
        case .complete, .failed: false
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Group {
                if model.translation.isEmpty {
                    Text(model.original)
                        .foregroundStyle(.secondary.opacity(0.48))
                } else {
                    Text(model.translation)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .transition(.opacity)
                }
            }
            .font(.system(size: 14))
            .fixedSize(horizontal: false, vertical: true)

            if isMoving {
                if reduceMotion {
                    HStack {
                        Spacer()
                        ProgressView().controlSize(.small)
                    }
                } else {
                    TideParticleWave(phase: model.tidePhase)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(minHeight: 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(model.translation.isEmpty ? "Translating" : "Translation")
        .accessibilityValue(model.translation.isEmpty ? model.original : model.translation)
        .animation(reduceMotion ? .easeOut(duration: 0.16) : .easeInOut(duration: 0.28),
                   value: model.translation.isEmpty)
    }
}

private struct TideParticleWave: View {
    let phase: TranslationPopupModel.TidePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { graphics, size in
                guard size.width > 0, size.height > 0 else { return }
                let seconds = context.date.timeIntervalSinceReferenceDate
                let speed = phase == .settling ? 1.8 : 0.78
                let progress = (seconds * speed).truncatingRemainder(dividingBy: 1.0)
                let frontier = CGFloat(progress) * (size.width + 70) - 24

                for index in 0..<32 {
                    let row = index % 7
                    let trail = index / 7
                    let x = frontier - CGFloat(trail * 13) - CGFloat(row % 2) * 4
                    let normalizedRow = CGFloat(row) / 6
                    let wave = sin(CGFloat(seconds * 4.2) + CGFloat(index) * 0.72) * 5
                    let y = normalizedRow * max(1, size.height - 6) + 3 + wave
                    guard x > -8, x < size.width + 8 else { continue }

                    let radius = CGFloat(1.2 + Double((index * 7) % 5) * 0.27)
                    let fade = max(0.15, 0.78 - Double(trail) * 0.13)
                    let color = index.isMultiple(of: 3)
                        ? Color.cyan.opacity(fade)
                        : TypeTideTheme.accent.opacity(fade)
                    graphics.fill(
                        Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                              width: radius * 2, height: radius * 2)),
                        with: .color(color)
                    )
                }
            }
        }
        .mask(
            LinearGradient(colors: [.clear, .white, .white, .clear],
                           startPoint: .leading, endPoint: .trailing)
        )
    }
}
