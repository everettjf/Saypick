//
//  PreferencesSection.swift
//  Saypick
//

import SwiftUI

enum PreferencesSection: String, CaseIterable, Identifiable {
    case general = "General"
    case behavior = "Behavior"
    case backend = "Backend"
    case language = "Language"
    case models = "Ollama Models"
    case shortcuts = "Shortcuts"
    case skipApps = "Skip Apps"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .behavior: return "wand.and.stars"
        case .backend: return "server.rack"
        case .language: return "globe"
        case .models: return "cpu"
        case .shortcuts: return "keyboard.fill"
        case .skipApps: return "nosign"
        case .about: return "info.circle.fill"
        }
    }

    /// 侧栏彩色徽标的 tint（与各页面分区标题保持一致）
    var tint: Color {
        switch self {
        case .general: return .blue
        case .behavior: return .purple
        case .backend: return .teal
        case .language: return .green
        case .models: return .orange
        case .shortcuts: return .pink
        case .skipApps: return .red
        case .about: return .gray
        }
    }
}
