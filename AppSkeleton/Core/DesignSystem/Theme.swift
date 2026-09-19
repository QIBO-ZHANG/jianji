import SwiftUI

/// Design tokens. Screens use these instead of raw numbers and ad-hoc colors so a
/// restyle touches one file.
enum Theme {
    enum Spacing: CGFloat, CaseIterable {
        case xs = 4, small = 8, medium = 12, large = 16, xl = 24, xxl = 32
    }

    enum Radius: CGFloat {
        case card = 12, control = 8, pill = 999
    }

    enum Palette {
        /// Brand color (#222222 in light mode, adaptive inverse in dark mode).
        static let primary = Color("AccentColor")
        static let background = Color(uiColor: .systemGroupedBackground)
        static let surface = Color(uiColor: .secondarySystemGroupedBackground)
        static let label = Color(uiColor: .label)
        static let secondaryLabel = Color(uiColor: .secondaryLabel)
        static let separator = Color(uiColor: .separator)
        static let positive = Color(uiColor: .systemGreen)
        static let negative = Color(uiColor: .systemRed)
    }

    enum Typography {
        static let title = Font.system(.title2, design: .rounded).weight(.semibold)
        static let headline = Font.system(.headline)
        static let body = Font.system(.body)
        static let caption = Font.system(.caption)
        static let mono = Font.system(.caption, design: .monospaced)
    }
}

/// Elevated container used by most content blocks.
struct CardModifier: ViewModifier {
    var padding: Theme.Spacing = .large

    func body(content: Content) -> some View {
        content
            .padding(padding.rawValue)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card.rawValue, style: .continuous))
    }
}

extension View {
    func card(padding: Theme.Spacing = .large) -> some View {
        modifier(CardModifier(padding: padding))
    }
}
