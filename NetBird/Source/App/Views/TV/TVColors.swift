//
//  TVColors.swift
//  NetBird
//
//  Modified for Trentfinity VPN on 2026-11-05: original vector mark and palette.
//
//  Shared styling definitions for tvOS views.
//  Provides colors and layout constants for the 10-foot TV experience.
//

import SwiftUI

#if os(tvOS)
import UIKit

// MARK: - TVColors

/// Centralized color definitions for all tvOS views.
/// Uses named colors from asset catalog with sensible fallbacks.
struct TVColors {

    // MARK: - Text Colors

    static var textPrimary: Color {
        colorOrFallback("TextPrimary", fallback: .primary)
    }

    static var textSecondary: Color {
        colorOrFallback("TextSecondary", fallback: .secondary)
    }

    static var textAlert: Color {
        colorOrFallback("TextAlert", fallback: .white)
    }

    // MARK: - Background Colors

    static var bgMenu: Color {
        colorOrFallback("BgMenu", fallback: Color(white: 0.1))
    }

    static var bgPrimary: Color {
        colorOrFallback("BgPrimary", fallback: Color(white: 0.15))
    }

    static var bgSecondary: Color {
        colorOrFallback("BgSecondary", fallback: Color(white: 0.08))
    }

    static var bgSideDrawer: Color {
        colorOrFallback("BgSideDrawer", fallback: Color(white: 0.2))
    }

    // MARK: - Gradient Colors

    /// Top-leading color for the full-screen gradient background.
    static var gradientTop: Color {
        Color(red: 16 / 255, green: 42 / 255, blue: 67 / 255)
    }

    /// Bottom-trailing color for the full-screen gradient background.
    static var gradientBottom: Color {
        Color(red: 8 / 255, green: 19 / 255, blue: 33 / 255)
    }

    // MARK: - Helper

    private static func colorOrFallback(_ name: String, fallback: Color) -> Color {
        UIColor(named: name) != nil ? Color(name) : fallback
    }
}

// MARK: - Trentfinity branding

/// Original vector artwork, drawn in SwiftUI so the TV wordmark stays crisp.
struct TrentfinityTVBrand: View {
    var markSize: CGFloat = 48
    var textSize: CGFloat = 26

    var body: some View {
        HStack(spacing: markSize * 0.22) {
            TrentfinityTVMark()
                .frame(width: markSize, height: markSize)

            VStack(alignment: .leading, spacing: 1) {
                Text("Trentfinity")
                    .font(.system(size: textSize, weight: .semibold, design: .rounded))
                Text("VPN")
                    .font(.system(size: textSize * 0.48, weight: .bold))
                    .tracking(textSize * 0.13)
            }
            .foregroundColor(Color(red: 237 / 255, green: 249 / 255, blue: 1))
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trentfinity VPN")
    }
}

struct TrentfinityTVMark: View {
    private let cyan = Color(red: 109 / 255, green: 231 / 255, blue: 224 / 255)
    private let teal = Color(red: 38 / 255, green: 191 / 255, blue: 180 / 255)

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                TrentfinityShieldShape()
                    .fill(LinearGradient(
                        colors: [TVColors.gradientTop, TVColors.gradientBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                TrentfinityShieldShape()
                    .stroke(
                        LinearGradient(colors: [cyan, teal], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: size * 0.035, lineCap: .round, lineJoin: .round)
                    )
                TrentfinityInfinityShape()
                    .stroke(cyan, style: StrokeStyle(lineWidth: size * 0.065, lineCap: .round, lineJoin: .round))
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct TrentfinityShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }

        var path = Path()
        path.move(to: point(0.5, 0.06))
        path.addLine(to: point(0.88, 0.20))
        path.addLine(to: point(0.85, 0.57))
        path.addCurve(to: point(0.5, 0.95), control1: point(0.81, 0.75), control2: point(0.66, 0.88))
        path.addCurve(to: point(0.15, 0.57), control1: point(0.34, 0.88), control2: point(0.19, 0.75))
        path.addLine(to: point(0.12, 0.20))
        path.closeSubpath()
        return path
    }
}

private struct TrentfinityInfinityShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }

        var path = Path()
        path.move(to: point(0.5, 0.44))
        path.addCurve(to: point(0.22, 0.44), control1: point(0.38, 0.18), control2: point(0.22, 0.24))
        path.addCurve(to: point(0.5, 0.44), control1: point(0.22, 0.64), control2: point(0.38, 0.70))
        path.addCurve(to: point(0.78, 0.44), control1: point(0.62, 0.18), control2: point(0.78, 0.24))
        path.addCurve(to: point(0.5, 0.44), control1: point(0.78, 0.64), control2: point(0.62, 0.70))
        path.move(to: point(0.5, 0.49))
        path.addLine(to: point(0.5, 0.75))
        return path
    }
}

// MARK: - TVLayout

/// Centralized layout constants for tvOS.
/// All dimensions optimized for the "10-foot experience" (viewing from couch distance).
struct TVLayout {

    // MARK: - Content Padding

    /// Standard content padding from screen edges
    static let contentPadding: CGFloat = 80

    /// Padding inside cards/sections
    static let cardPadding: CGFloat = 30

    /// Padding inside detail panels
    static let detailPadding: CGFloat = 40

    /// Padding for dialog/alert content
    static let dialogPadding: CGFloat = 60

    // MARK: - Spacing

    /// Large spacing between major sections
    static let sectionSpacing: CGFloat = 40

    /// Medium spacing between related elements
    static let elementSpacing: CGFloat = 20

    /// Small spacing within grouped items
    static let itemSpacing: CGFloat = 15

    /// Horizontal spacing between columns
    static let columnSpacing: CGFloat = 100

    /// Spacing between filter buttons
    static let filterSpacing: CGFloat = 35

    // MARK: - Sizes

    /// Logo width on main screens (brand anchor, top-left)
    static let logoWidth: CGFloat = 150

    /// Logo width on secondary screens (dialogs, info panels)
    static let logoWidthSmall: CGFloat = 200

    /// Side panel/detail view width
    static let sidePanelWidth: CGFloat = 500

    /// Info panel width (server view, etc.)
    static let infoPanelWidth: CGFloat = 400

    /// QR code size for auth view
    static let qrCodeSize: CGFloat = 280

    // MARK: - Corner Radius

    /// Large corner radius for major containers
    static let cornerRadiusLarge: CGFloat = 24

    /// Medium corner radius for cards
    static let cornerRadiusMedium: CGFloat = 20

    /// Small corner radius for buttons/inputs
    static let cornerRadiusSmall: CGFloat = 12

    // MARK: - Font Sizes

    /// Page title (e.g., "Settings", "Peers")
    static let fontTitle: CGFloat = 48

    /// Section header
    static let fontHeader: CGFloat = 36

    /// Card title / primary text
    static let fontBody: CGFloat = 32

    /// Secondary/subtitle text
    static let fontSubtitle: CGFloat = 28

    /// Small/caption text
    static let fontCaption: CGFloat = 24

    /// Device code display (auth view)
    static let fontDeviceCode: CGFloat = 64

    // MARK: - Button Dimensions

    /// Horizontal padding for primary buttons
    static let buttonPaddingH: CGFloat = 50

    /// Vertical padding for primary buttons
    static let buttonPaddingV: CGFloat = 18

    /// Button font size
    static let buttonFontSize: CGFloat = 30

    // MARK: - Focus Effects

    /// Scale factor when element is focused
    static let focusScale: CGFloat = 1.02

    /// Scale factor for large focused buttons
    static let focusScaleLarge: CGFloat = 1.1

    /// Border width when focused
    static let focusBorderWidth: CGFloat = 4
}

#endif
