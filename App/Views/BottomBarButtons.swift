import SwiftUI

extension View {
    /// A bottom bar's labels stay on one line and shrink a little when two buttons share a row at the largest text
    /// sizes, rather than breaking mid-word; the text keeps the user's size wherever it fits.
    func bottomBarTextFit() -> some View {
        lineLimit(1).minimumScaleFactor(0.6)
    }

    /// A bottom bar's icon buttons: icons alone, or titles alone at accessibility sizes, where the bar has two rows.
    @ViewBuilder
    func bottomBarLabels(isLarge: Bool) -> some View {
        if isLarge {
            labelStyle(.titleOnly)
        } else {
            labelStyle(.iconOnly)
        }
    }
}
