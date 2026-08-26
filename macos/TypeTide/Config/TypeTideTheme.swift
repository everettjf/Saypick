import SwiftUI

/// Shared visual language for TypeTide surfaces.
/// Platform-native controls keep their native appearance; these tokens align
/// brand, spacing, status and custom chrome across the app.
enum TypeTideTheme {
    static let accent = Color(red: 0x7C / 255, green: 0x5C / 255, blue: 0xFF / 255)
    static let accentSoft = accent.opacity(0.12)

    static let success = Color.green
    static let warning = Color.orange
    static let danger = Color.red

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
        static let page: CGFloat = 28
    }

    enum Radius {
        static let control: CGFloat = 8
        static let card: CGFloat = 10
        static let popup: CGFloat = 12
    }

    enum Control {
        static let compactHeight: CGFloat = 28
        static let minimumHitSize: CGFloat = 28
        static let popupWidth: CGFloat = 400
        static let popupMaxHeight: CGFloat = 420
    }
}

enum TypeTideStatusStyle {
    case success
    case warning
    case error
    case neutral

    var color: Color {
        switch self {
        case .success: TypeTideTheme.success
        case .warning: TypeTideTheme.warning
        case .error: TypeTideTheme.danger
        case .neutral: .secondary
        }
    }

    var symbol: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        case .neutral: "info.circle.fill"
        }
    }
}
