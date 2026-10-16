import SwiftUI

extension View {
    /// A bottom bar's labels stay on one line and shrink a little when two buttons share a row at the largest text
    /// sizes, rather than breaking mid-word; the text keeps the user's size wherever it fits.
    func bottomBarTextFit() -> some View {
        lineLimit(1).minimumScaleFactor(0.6)
    }

    /// A bottom bar that stays put while the list scrolls: one full-width prominent button and, when it is
    /// disabled, a footnote saying why.
    func bottomBarButton(
        _ title: LocalizedStringKey, identifier: String, isEnabled: Bool = true,
        hint: LocalizedStringKey? = nil,
        hintIdentifier: String? = nil, action: @escaping () -> Void
    ) -> some View {
        safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button(action: action) {
                    Text(title).frame(maxWidth: .infinity)
                }
                .font(.headline)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isEnabled)
                .accessibilityIdentifier(identifier)
                if !isEnabled, let hint {
                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(hintIdentifier ?? "\(identifier).hint")
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
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
