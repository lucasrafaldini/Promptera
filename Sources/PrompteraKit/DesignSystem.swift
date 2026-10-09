import SwiftUI
import AppKit
import Observation

/// Design System - Promptera Color Palette & Visual Identity
///
/// The brand colors come from the active `PrompteraTheme` (default: "Midnight Aurora").
/// Every theme defines a light and a dark variant of its 3-stop gradient, so contrast
/// stays readable in both appearances.
/// - Success: Emerald Green (trust, growth)
/// - Warning: Amber (attention, caution)
/// - Error: Rose Red (danger, destructive)
/// - Surfaces: System-adaptive (respects Dark/Light mode)

// MARK: - Adaptive Color Helper

public extension Color {
    /// Creates a color that resolves differently in light and dark appearances.
    init(light: NSColor, dark: NSColor) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    /// Hex helper (0xRRGGBB).
    init(hex: UInt32, light: UInt32? = nil) {
        if let light {
            self.init(light: NSColor(hex: light), dark: NSColor(hex: hex))
        } else {
            self.init(nsColor: NSColor(hex: hex))
        }
    }
}

public extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

// MARK: - Themes

public enum PrompteraTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case aurora
    case ocean
    case sunset
    case forest
    case graphite

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .aurora: return "Aurora"
        case .ocean: return "Oceano"
        case .sunset: return "Pôr do Sol"
        case .forest: return "Floresta"
        case .graphite: return "Grafite"
        }
    }

    /// Gradient stops as (light, dark) hex pairs.
    private var stops: [(light: UInt32, dark: UInt32)] {
        switch self {
        case .aurora:   return [(0x4F46E5, 0x6366F1), (0x7C3AED, 0x8B5CF6), (0xB82EB8, 0xD946EF)]
        case .ocean:    return [(0x0369A1, 0x0284C7), (0x0E7490, 0x0891B2), (0x0F766E, 0x0D9488)]
        case .sunset:   return [(0xEA580C, 0xF97316), (0xE11D48, 0xF43F5E), (0xC026D3, 0xD946EF)]
        case .forest:   return [(0x047857, 0x059669), (0x15803D, 0x16A34A), (0x4D7C0F, 0x65A30D)]
        case .graphite: return [(0x475569, 0x64748B), (0x334155, 0x475569), (0x1E293B, 0x334155)]
        }
    }

    public var colors: [Color] {
        stops.map { Color(light: NSColor(hex: $0.light), dark: NSColor(hex: $0.dark)) }
    }

    public var primary: Color { colors[0] }
    public var secondary: Color { colors[1] }
    public var accent: Color { colors[2] }
}

public enum PrompteraAppearance: String, CaseIterable, Identifiable, Codable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "Sistema"
        case .light: return "Claro"
        case .dark: return "Escuro"
        }
    }

    public var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    public var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

/// Observable store for the user's theme choices. Because it uses the Observation
/// framework, any SwiftUI body that reads `PrompteraColors.brand*` (which reads
/// `ThemeStore.shared.theme`) re-renders automatically when the theme changes.
@Observable
public final class ThemeStore {
    public static let shared = ThemeStore()

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let themeKey = "promptera_theme"
    @ObservationIgnored private let appearanceKey = "promptera_appearance"

    public var theme: PrompteraTheme {
        didSet { defaults.set(theme.rawValue, forKey: themeKey) }
    }

    public var appearance: PrompteraAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: appearanceKey) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.theme = defaults.string(forKey: themeKey).flatMap(PrompteraTheme.init(rawValue:)) ?? .aurora
        self.appearance = defaults.string(forKey: appearanceKey).flatMap(PrompteraAppearance.init(rawValue:)) ?? .system
    }

    /// Applies the appearance to every app window (popover, save/open panels).
    @MainActor
    public func applyAppearance() {
        NSApp?.appearance = appearance.nsAppearance
    }
}

public enum PrompteraColors {
    private static var theme: PrompteraTheme { ThemeStore.shared.theme }

    // MARK: - Brand Gradient

    /// Primary brand gradient (diagonal)
    public static var brandGradient: LinearGradient {
        LinearGradient(colors: theme.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Subtle brand gradient for backgrounds
    public static var brandGradientSubtle: LinearGradient {
        LinearGradient(
            colors: [theme.primary.opacity(0.15), theme.secondary.opacity(0.1), theme.accent.opacity(0.15)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Horizontal brand gradient for horizontal elements
    public static var brandGradientHorizontal: LinearGradient {
        LinearGradient(colors: theme.colors, startPoint: .leading, endPoint: .trailing)
    }

    // MARK: - Semantic Colors

    public static var brandPrimary: Color { theme.primary }
    public static var brandSecondary: Color { theme.secondary }
    public static var brandAccent: Color { theme.accent }

    // MARK: - Status Colors

    /// Success: Emerald
    public static let success = Color(hex: 0x10B981, light: 0x059669)
    public static let successLight = Color(hex: 0x34D399)

    /// Warning: Amber
    public static let warning = Color(hex: 0xF59E0B, light: 0xD97706)
    public static let warningLight = Color(hex: 0xFBBF24)

    /// Error/Destructive: Rose
    public static let error = Color(hex: 0xF43F5E, light: 0xE11D48)
    public static let errorLight = Color(hex: 0xFB7185)

    // MARK: - Surface Colors (System Adaptive)

    public static let surfacePrimary = Color(nsColor: .windowBackgroundColor)
    public static let surfaceSecondary = Color(nsColor: .controlBackgroundColor)
    public static let surfaceTertiary = Color(nsColor: .controlBackgroundColor).opacity(0.6)
    public static var surfaceSelected: Color { theme.primary.opacity(0.12) }

    // MARK: - Border Colors

    public static let borderSubtle = Color.secondary.opacity(0.12)
    public static let borderDefault = Color.secondary.opacity(0.18)
    public static var borderEmphasized: Color { theme.primary.opacity(0.4) }

    // MARK: - Text Colors (System Adaptive)

    public static let textPrimary = Color.primary
    public static let textSecondary = Color.secondary
    public static let textTertiary = Color.secondary.opacity(0.5)
    public static let textOnBrand = Color.white

    // MARK: - Shadow Colors

    public static let shadowSubtle = Color.black.opacity(0.06)
    public static let shadowDefault = Color.black.opacity(0.1)
    public static let shadowElevated = Color.black.opacity(0.15)
    public static var shadowBrand: Color { theme.primary.opacity(0.25) }
}

// MARK: - Brand Shapes

/// Four-point sparkle used by the app icon, the header logo and the menu bar icon.
public struct SparkleShape: Shape {
    /// How pinched the star's waist is (0 = diamond, 1 = very thin).
    public var pinch: CGFloat

    public init(pinch: CGFloat = 0.82) {
        self.pinch = pinch
    }

    public func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let k = r * (1 - pinch) * 0.7
        var path = Path()
        path.move(to: CGPoint(x: c.x, y: c.y - r))
        path.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
        path.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
        path.closeSubpath()
        return path
    }
}

/// In-app rendition of the app icon: gradient squircle with sparkles.
public struct PrompteraLogo: View {
    public var size: CGFloat

    public init(size: CGFloat = 28) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous)
                .fill(PrompteraColors.brandGradient)
            SparkleShape()
                .fill(.white)
                .frame(width: size * 0.56, height: size * 0.56)
                .offset(x: -size * 0.04, y: size * 0.04)
            SparkleShape()
                .fill(.white.opacity(0.85))
                .frame(width: size * 0.2, height: size * 0.2)
                .offset(x: size * 0.24, y: -size * 0.24)
        }
        .frame(width: size, height: size)
        .shadow(color: PrompteraColors.shadowBrand, radius: size * 0.12, x: 0, y: size * 0.06)
        .accessibilityHidden(true)
    }
}

/// Template image for the menu bar (adapts to light/dark menu bars automatically).
public enum MenuBarIcon {
    public static func image(generating: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: true) { rect in
            let big = SparkleShape().path(in: CGRect(x: 1, y: 3, width: 13, height: 13))
            let small = SparkleShape().path(in: CGRect(x: 11.5, y: 0.5, width: 6, height: 6))
            NSColor.black.setFill()
            NSColor.black.setStroke()
            let bigPath = NSBezierPath(cgPath: big.cgPath)
            if generating {
                bigPath.lineWidth = 1.4
                bigPath.stroke()
            } else {
                bigPath.fill()
            }
            NSBezierPath(cgPath: small.cgPath).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Promptera"
        return image
    }
}

private extension NSBezierPath {
    convenience init(cgPath: CGPath) {
        self.init()
        cgPath.applyWithBlock { element in
            let p = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint: move(to: p[0])
            case .addLineToPoint: line(to: p[0])
            case .addQuadCurveToPoint:
                let start = currentPoint
                let cp1 = CGPoint(x: start.x + 2 / 3 * (p[0].x - start.x), y: start.y + 2 / 3 * (p[0].y - start.y))
                let cp2 = CGPoint(x: p[1].x + 2 / 3 * (p[0].x - p[1].x), y: p[1].y + 2 / 3 * (p[0].y - p[1].y))
                curve(to: p[1], controlPoint1: cp1, controlPoint2: cp2)
            case .addCurveToPoint: curve(to: p[2], controlPoint1: p[0], controlPoint2: p[1])
            case .closeSubpath: close()
            @unknown default: break
            }
        }
    }
}

// MARK: - View Extensions

public extension View {
    /// Apply brand gradient as foreground style
    func brandGradientForeground() -> some View {
        self.foregroundStyle(PrompteraColors.brandGradient)
    }

    /// Apply subtle brand gradient background
    func brandGradientBackground() -> some View {
        self.background(PrompteraColors.brandGradientSubtle)
    }

    /// Apply brand gradient border
    func brandGradientBorder(lineWidth: CGFloat = 1) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(PrompteraColors.brandGradient, lineWidth: lineWidth)
        )
    }

    /// Apply success state styling
    func successStyle() -> some View {
        self.foregroundStyle(PrompteraColors.success)
    }

    /// Apply warning state styling
    func warningStyle() -> some View {
        self.foregroundStyle(PrompteraColors.warning)
    }

    /// Apply error state styling
    func errorStyle() -> some View {
        self.foregroundStyle(PrompteraColors.error)
    }

    /// Card styling with subtle shadow and border
    func cardStyle(cornerRadius: CGFloat = 12, elevated: Bool = false) -> some View {
        self
            .background(PrompteraColors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(PrompteraColors.borderDefault, lineWidth: 1)
            )
            .shadow(
                color: elevated ? PrompteraColors.shadowElevated : PrompteraColors.shadowSubtle,
                radius: elevated ? 12 : 6,
                x: 0,
                y: elevated ? 6 : 3
            )
    }

    /// Selected card style
    func selectedCardStyle(cornerRadius: CGFloat = 12) -> some View {
        self
            .background(PrompteraColors.surfaceSelected)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(PrompteraColors.brandPrimary, lineWidth: 1.5)
            )
            .shadow(color: PrompteraColors.shadowBrand, radius: 8, x: 0, y: 4)
    }

    /// Hover scale effect
    func hoverScale(_ scale: CGFloat = 1.01) -> some View {
        self.scaleEffect(scale)
    }

    /// Pressed scale effect
    func pressScale(_ scale: CGFloat = 0.98) -> some View {
        self.scaleEffect(scale)
    }
}

// MARK: - Button Styles

/// Primary call-to-action: brand gradient fill, white label, press feedback.
/// Unlike `.borderedProminent`, it keeps the theme colors even when the window is inactive.
public struct BrandButtonStyle: ButtonStyle {
    public var cornerRadius: CGFloat
    @Environment(\.isEnabled) private var isEnabled

    public init(cornerRadius: CGFloat = 10) {
        self.cornerRadius = cornerRadius
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(PrompteraColors.textOnBrand)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(PrompteraColors.brandGradientHorizontal)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.black.opacity(configuration.isPressed ? 0.15 : 0))
                    )
            )
            .shadow(color: isEnabled ? PrompteraColors.shadowBrand : .clear, radius: 6, x: 0, y: 3)
            .opacity(isEnabled ? 1 : 0.45)
            .saturation(isEnabled ? 1 : 0.3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
