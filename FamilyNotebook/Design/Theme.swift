import SwiftUI
import UIKit

enum Theme {
    // Warm paper palette (light / dark)
    static let paper = dynamic(0xF6F3EE, 0x161514)
    static let card = dynamic(0xFFFFFF, 0x201F1D)
    static let cardRaised = dynamic(0xFFFFFF, 0x262522)
    static let ink = dynamic(0x23211E, 0xEDEAE4)
    static let inkSecondary = dynamic(0x6E6A64, 0xA19D96)
    static let inkTertiary = dynamic(0xA39E96, 0x6F6B65)
    static let hairline = dynamic(0xE7E2DA, 0x2E2C29)

    static let accent = dynamic(0x3F8A4F, 0x79C08A)
    static let accentSoft = dynamic(0xDDEBDD, 0x1E3322)
    static let journal = dynamic(0x6E56CF, 0xA391F2)
    static let journalSoft = dynamic(0xECE8F6, 0x2A2540)
    static let trip = dynamic(0x136F7F, 0x4FB3C4)
    static let tripSoft = dynamic(0xE0ECEE, 0x1B2E31)
    static let warning = dynamic(0xD9541E, 0xF08A5D)

    static let uiInk = uiDynamic(0x23211E, 0xEDEAE4)
    static let uiInkSecondary = uiDynamic(0x6E6A64, 0xA19D96)
    static let uiAccent = uiDynamic(0x3F8A4F, 0x79C08A)
    static let uiPaper = uiDynamic(0xF6F3EE, 0x161514)
    static let uiCard = uiDynamic(0xFFFFFF, 0x201F1D)

    static func uiDynamic(_ light: UInt32, _ dark: UInt32) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) }
    }

    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: uiDynamic(light, dark))
    }

    // Typography: New York serif for writing & headings, SF for UI chrome.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func serif(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .serif).weight(weight)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

// MARK: - Reusable bits

struct CardBackground: ViewModifier {
    var radius: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.75))
            .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
    }
}

extension View {
    func card(radius: CGFloat = 20) -> some View { modifier(CardBackground(radius: radius)) }

    func paperBackground() -> some View {
        background(Theme.paper.ignoresSafeArea())
    }
}

struct Avatar: View {
    var name: String?
    var size: CGFloat = 26

    var body: some View {
        Text(String((name ?? "?").prefix(1)).uppercased())
            .font(.system(size: size * 0.46, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(People.color(for: name), in: Circle())
            .overlay(Circle().strokeBorder(Theme.card, lineWidth: size > 24 ? 2 : 1.5))
            .accessibilityLabel(name ?? "")
    }
}

struct AvatarPair: View {
    var size: CGFloat = 24
    var body: some View {
        HStack(spacing: -size * 0.3) {
            Avatar(name: People.personA, size: size)
            Avatar(name: People.personB, size: size)
        }
    }
}

struct Chip: View {
    var text: String
    var tint: Color = Theme.accent
    var symbol: String?

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.caption2.weight(.bold)) }
            Text(text).font(.caption.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.14), in: Capsule())
    }
}

struct SectionHeader: View {
    var title: String
    var trailing: String?
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(Theme.display(22))
                .foregroundStyle(Theme.ink)
            Spacer()
            if let trailing {
                Text(trailing).font(.subheadline).foregroundStyle(Theme.inkSecondary)
            }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(tint, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.3, bounce: 0.4), value: configuration.isPressed)
    }
}

extension Date {
    var relativeShort: String {
        let interval = Date.now.timeIntervalSince(self)
        if interval < 60 { return "just now" }
        return formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    }
}
