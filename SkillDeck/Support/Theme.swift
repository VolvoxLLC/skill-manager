import SwiftUI

/// Centralized design tokens and Liquid Glass helpers for the SkillDeck UI.
///
/// The accent color intentionally mirrors the user's system-wide accent
/// (System Settings → Appearance → Accent color) rather than a bundled asset,
/// so the app inherits whatever the user picked at the OS level.
enum Theme {
    /// Corner radius used for Liquid Glass cards and grouped content.
    static let cardCornerRadius: CGFloat = 16

    /// Spacing between sibling glass-styled elements.
    static let glassSpacing: CGFloat = 12

    /// Standard inset for content padded against a glass surface.
    static let contentPadding: CGFloat = 16
}

extension Color {
    /// The accent color the user selected in macOS System Settings.
    ///
    /// Bridges `NSColor.controlAccentColor` so the value tracks the live system
    /// preference even when the app ships no `AccentColor` asset override.
    static var systemAccent: Color {
        Color(nsColor: .controlAccentColor)
    }
}

extension View {
    /// Wraps the view in a Liquid Glass card with the standard corner radius.
    ///
    /// - Parameter interactive: When `true`, the glass reacts to pointer and
    ///   press interactions, suitable for tappable rows and controls.
    /// - Returns: A view rendered on a Liquid Glass surface.
    @ViewBuilder
    func glassCard(interactive: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            let glass: Glass = interactive ? .regular.interactive() : .regular
            self.glassEffect(glass, in: .rect(cornerRadius: Theme.cardCornerRadius))
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .strokeBorder(Color.glassStroke)
                }
        }
    }

    @ViewBuilder
    func glassCapsule(interactive: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            let glass: Glass = interactive ? .regular.interactive() : .regular
            self.glassEffect(glass, in: .capsule)
        } else {
            self
                .background(.thinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(Color.glassStroke)
                }
        }
    }
}
