import SwiftUI

enum MedkitTheme {
    // Primary accent — warm coral-red (Claude-ish but redder)
    static let accent = Color(red: 0.83, green: 0.35, blue: 0.30)       // #D4594D
    static let accentSoft = Color(red: 0.92, green: 0.62, blue: 0.58)   // #EB9E94
    static let accentVeryLight = Color(red: 0.98, green: 0.92, blue: 0.91) // #FAEBE8

    // Background gradient
    static let gradientTop = Color(red: 0.99, green: 0.93, blue: 0.91)  // #FDEDE8
    static let gradientBottom = Color.white

    // Text
    static let textPrimary = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let textSecondary = Color(red: 0.45, green: 0.45, blue: 0.47)

    // Surfaces
    static let cardBackground = Color.white
    static let sessionBackground = Color(red: 0.965, green: 0.965, blue: 0.97)
    static let darkSurface = Color(red: 0.14, green: 0.14, blue: 0.16)
}
