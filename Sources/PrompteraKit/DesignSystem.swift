import SwiftUI

/// Design System - Promptera Color Palette & Visual Identity
///
/// New Brand Palette: "Midnight Aurora"
/// - Primary: Deep Indigo → Violet gradient (tech-forward, premium)
/// - Success: Emerald Green (trust, growth)
/// - Warning: Amber (attention, caution)
/// - Error: Rose Red (danger, destructive)
/// - Surfaces: System-adaptive (respects Dark/Light mode)

public enum PrompteraColors {
    // MARK: - Brand Gradient
    
    /// Primary brand gradient: Indigo → Violet → Fuchsia
    public static let brandGradient = LinearGradient(
        colors: [
            Color(red: 0.31, green: 0.27, blue: 0.89),  // Indigo 600
            Color(red: 0.49, green: 0.23, blue: 0.93),  // Violet 600
            Color(red: 0.72, green: 0.18, blue: 0.72)   // Fuchsia 600
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Subtle brand gradient for backgrounds
    public static let brandGradientSubtle = LinearGradient(
        colors: [
            Color(red: 0.31, green: 0.27, blue: 0.89).opacity(0.15),
            Color(red: 0.49, green: 0.23, blue: 0.93).opacity(0.1),
            Color(red: 0.72, green: 0.18, blue: 0.72).opacity(0.15)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Horizontal brand gradient for horizontal elements
    public static let brandGradientHorizontal = LinearGradient(
        colors: [
            Color(red: 0.31, green: 0.27, blue: 0.89),
            Color(red: 0.49, green: 0.23, blue: 0.93),
            Color(red: 0.72, green: 0.18, blue: 0.72)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // MARK: - Semantic Colors
    
    /// Primary brand color (Indigo 600)
    public static let brandPrimary = Color(red: 0.31, green: 0.27, blue: 0.89)
    
    /// Secondary brand color (Violet 600)
    public static let brandSecondary = Color(red: 0.49, green: 0.23, blue: 0.93)
    
    /// Accent brand color (Fuchsia 600)
    public static let brandAccent = Color(red: 0.72, green: 0.18, blue: 0.72)
    
    // MARK: - Status Colors
    
    /// Success: Emerald 600
    public static let success = Color(red: 0.05, green: 0.59, blue: 0.41)
    public static let successLight = Color(red: 0.16, green: 0.73, blue: 0.55)
    
    /// Warning: Amber 600
    public static let warning = Color(red: 0.85, green: 0.47, blue: 0.04)
    public static let warningLight = Color(red: 0.96, green: 0.62, blue: 0.11)
    
    /// Error/Destructive: Rose 600
    public static let error = Color(red: 0.88, green: 0.11, blue: 0.28)
    public static let errorLight = Color(red: 0.97, green: 0.24, blue: 0.37)
    
    // MARK: - Surface Colors (System Adaptive)
    
    /// Primary content surface
    public static let surfacePrimary = Color(NSColor.windowBackgroundColor)
    
    /// Secondary content surface (cards, panels)
    public static let surfaceSecondary = Color(NSColor.controlBackgroundColor)
    
    /// Tertiary surface (hover states, subtle backgrounds)
    public static let surfaceTertiary = Color(NSColor.controlBackgroundColor).opacity(0.6)
    
    /// Selected/active surface
    public static let surfaceSelected = Color(NSColor.selectedContentBackgroundColor).opacity(0.2)
    
    // MARK: - Border Colors
    
    /// Subtle border
    public static let borderSubtle = Color.secondary.opacity(0.12)
    
    /// Default border
    public static let borderDefault = Color.secondary.opacity(0.18)
    
    /// Emphasized border (focus, selection)
    public static let borderEmphasized = Color(red: 0.31, green: 0.27, blue: 0.89).opacity(0.4)
    
    // MARK: - Text Colors (System Adaptive)
    
    /// Primary text
    public static let textPrimary = Color.primary
    
    /// Secondary text
    public static let textSecondary = Color.secondary
    
    /// Tertiary text (placeholders, hints)
    public static let textTertiary = Color.secondary.opacity(0.5)
    
    /// Inverse text (on brand colors)
    public static let textOnBrand = Color.white
    
    // MARK: - Shadow Colors
    
    /// Subtle shadow
    public static let shadowSubtle = Color.black.opacity(0.06)
    
    /// Default shadow
    public static let shadowDefault = Color.black.opacity(0.1)
    
    /// Elevated shadow
    public static let shadowElevated = Color.black.opacity(0.15)
    
    /// Brand shadow
    public static let shadowBrand = Color(red: 0.31, green: 0.27, blue: 0.89).opacity(0.25)
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
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
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
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
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