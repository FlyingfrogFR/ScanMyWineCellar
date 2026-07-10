import SwiftUI

// Note: Color.cellarBackground, .cellarSurface, and .cellarCell are
// generated automatically from the asset catalog (asset symbol extensions),
// so they are not declared here.

extension View {
    /// Themed backdrop for Forms and Lists: hides the system grouped
    /// background and shows the cellar ground instead.
    func cellarChrome() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.cellarBackground)
    }
}
