import SwiftUI

/// Cellar palette from the design system: plum-charcoal ground, panel
/// surfaces, and chalk cards in dark mode; warm paper tones in light.
extension Color {
    static let cellarBackground = Color("CellarBackground")
    static let cellarSurface = Color("CellarSurface")
    static let cellarCell = Color("CellarCell")
}

extension View {
    /// Themed backdrop for Forms and Lists: hides the system grouped
    /// background and shows the cellar ground instead.
    func cellarChrome() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.cellarBackground)
    }
}
