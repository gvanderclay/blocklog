import SwiftUI

/// A compact list of exercise names to drag into a new order; Done hands the new order to `onDone`.
struct ReorderSheet<Item: Identifiable>: View {
    let name: (Item) -> String
    /// Applies the order; a thrown error shows the save-failed alert and keeps the sheet open.
    let onDone: ([Item]) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var order: [Item]
    @State private var saveFailed = false

    init(items: [Item], name: @escaping (Item) -> String, onDone: @escaping ([Item]) throws -> Void)
    {
        self.name = name
        self.onDone = onDone
        self.order = items
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(order.enumerated(), id: \.element.id) { index, item in
                    Text(name(item))
                        .accessibilityIdentifier("reorder.row.\(index)")
                }
                .onMove { order.move(fromOffsets: $0, toOffset: $1) }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        do {
                            try onDone(order)
                            dismiss()
                        } catch {
                            saveFailed = true
                        }
                    }
                    .accessibilityIdentifier("reorder.done")
                }
            }
            .saveFailedAlert(isPresented: $saveFailed)
        }
        .presentationDetents([.medium])
    }
}
