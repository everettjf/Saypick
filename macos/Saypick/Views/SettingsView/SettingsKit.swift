//
//  SettingsKit.swift
//  Saypick
//
//  设置页共用视觉组件：彩色徽标、带副标题的分区标题、信息提示、统一页面容器。
//  目标：System Settings 风格的彩色图标徽标 + 卡片分组，跨页面保持一致。
//

import SwiftUI

/// 彩色圆角图标徽标（System Settings 风格）
struct IconBadge: View {
    let symbol: String
    var color: Color = .blue
    var size: CGFloat = 22

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(color.gradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.54, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .shadow(color: color.opacity(0.3), radius: 1.5, y: 0.5)
    }
}

/// 分区标题：彩色徽标 + 标题 + 可选副标题（放进 `Section(header:)`）
struct SettingsSectionHeader: View {
    let symbol: String
    var color: Color = .blue
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            IconBadge(symbol: symbol, color: color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .textCase(nil)          // 取消 grouped form 默认的全大写
        .padding(.vertical, 2)
    }
}

/// 行内彩色徽标 + 文本（用于 Toggle / 普通行的 label）
struct SettingsLabel: View {
    let symbol: String
    var color: Color = .blue
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            IconBadge(symbol: symbol, color: color, size: 20)
            Text(title)
        }
    }
}

/// 灰色信息提示（图标 + 小字，自动换行）
struct SettingsNote: View {
    let text: String
    var symbol: String = "info.circle"
    var tint: Color = .secondary

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(tint)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension View {
    /// 统一的设置页容器：grouped form + 标题；去掉各页各自的 `.padding()`（grouped 自带边距）。
    func settingsPage(_ title: String) -> some View {
        self
            .formStyle(.grouped)
            .navigationTitle(title)
    }
}
