import SwiftUI
import UIKit

/// Design tokens. Screens use these instead of raw numbers and ad-hoc colors so a
/// restyle touches one file.
///
/// Light palette follows the 首页 mockup: pale-blue page, white cards, blue for
/// interaction (checkmarks, reminders, selection), orange reserved for flags.
enum Theme {
    enum Spacing: CGFloat, CaseIterable {
        case xs = 4, small = 8, medium = 12, large = 16, xl = 24, xxl = 32
    }

    enum Radius: CGFloat {
        case card = 12, sheet = 24, control = 8, pill = 999
    }

    enum Palette {
        /// Interactive accent (checkmarks, reminders, selected states) — blue.
        static let primary = Color("AccentColor")
        /// Flagged/important marker — orange.
        static let flag = dynamic(light: 0xFF8A00, dark: 0xFFB340)
        /// Pale-blue page wash behind everything.
        static let background = dynamic(light: 0xC7D9EA, dark: 0x141F2B)
        /// Elevated card surface floating on the page wash.
        static let surface = dynamic(light: 0xFFFFFF, dark: 0x1D2B39)
        static let label = Color(uiColor: .label)
        static let secondaryLabel = Color(uiColor: .secondaryLabel)
        static let separator = dynamic(light: 0xD7E2ED, dark: 0x324150)
        static let positive = Color(uiColor: .systemGreen)
        static let negative = Color(uiColor: .systemRed)

        private static func dynamic(light: UInt32, dark: UInt32) -> Color {
            Color(uiColor: UIColor { trait in
                UIColor(hex: trait.userInterfaceStyle == .dark ? dark : light)
            })
        }
    }

    enum Typography {
        static let title = Font.system(.title2, design: .rounded).weight(.semibold)
        static let headline = Font.system(.headline)
        static let body = Font.system(.body)
        static let caption = Font.system(.caption)
        static let mono = Font.system(.caption, design: .monospaced)
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
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

/// Dotted rule between rows, per the mockup.
struct DashedSeparator: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: size.width, y: 0))
            context.stroke(
                path,
                with: .color(Theme.Palette.separator),
                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
            )
        }
        .frame(height: 1)
    }
}

extension View {
    func card(padding: Theme.Spacing = .large) -> some View {
        modifier(CardModifier(padding: padding))
    }

    /// Liquid-glass pills/circles for the custom todo header; falls back to a
    /// material on OS versions without glassEffect.
    @ViewBuilder
    func glassCapsule<S: Shape>(_ shape: S = Capsule()) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
        }
    }
}
