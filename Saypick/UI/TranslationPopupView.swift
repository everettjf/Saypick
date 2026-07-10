//
//  TranslationPopupView.swift
//  Saypick
//
//  划词翻译弹窗内容（流式展示）。
//

import SwiftUI
import AppKit
import Combine

@MainActor
final class TranslationPopupModel: ObservableObject {
    @Published var original: String
    @Published var translation: String = ""
    @Published var isLoading: Bool = true
    @Published var errorText: String?
    /// 当前目标语言（弹窗顶部可改选，触发 onRetarget 重新翻译）
    @Published var targetLanguage: Language

    /// 复制译文
    var onCopy: (() -> Void)?
    /// 替换原文（读模式可选；为 nil 时不显示）
    var onReplace: (() -> Void)?
    /// 用户在弹窗里改选目标语言时回调（按新目标重新翻译）
    var onRetarget: ((Language) -> Void)?

    init(original: String, target: Language) {
        self.original = original
        self.targetLanguage = target
    }
}

struct TranslationPopupView: View {
    @ObservedObject var model: TranslationPopupModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 380)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 6)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: BrandIcon.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.blue.opacity(0.85))
            Text("Saypick")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
            targetMenu
            Button {
                PopupController.shared.close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
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
            .foregroundColor(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let err = model.errorText {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if model.translation.isEmpty && model.isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Translating…")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            } else {
                Text(model.translation)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !model.translation.isEmpty && model.errorText == nil {
                HStack(spacing: 10) {
                    Spacer()
                    Button {
                        model.onCopy?()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

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
