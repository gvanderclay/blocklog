import SwiftUI

/// A read-only preview of a block change during rest: the diagram opens at the weight just done, then
/// moves to the next set's. It animates its own local weight, so no recorded weight changes.
struct ChangePreviewSheet: View {
    let now: Double
    let next: Double

    @Environment(\.dismiss) private var dismiss
    @State private var shown: Double

    init(now: Double, next: Double) {
        self.now = now
        self.next = next
        _shown = State(initialValue: now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    PowerBlockDiagram(weight: shown)
                    Text(
                        "\(PowerBlockTable.setupLine(for: now) ?? "") → \(PowerBlockTable.setupLine(for: next) ?? "")"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("diagram.caption")
                }
                .padding()
            }
            .navigationTitle("Block Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("diagram.done")
                }
            }
        }
        .presentationDetents([.medium, .large])
        // Cancelled with the sheet, so closing early stops the pending move.
        .task {
            try? await Task.sleep(for: .milliseconds(500))
            if !Task.isCancelled { shown = next }
        }
    }
}
