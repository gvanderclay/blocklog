import SwiftUI

/// A side view of the PowerBlock stack set up for a weight: the handle and eight plate rails, the pin at its
/// rail, and the two adders on the handle. The weight is the only input; any change of it animates.
@MainActor
struct PowerBlockDiagram: View {
    let weight: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .footnote) private var rowHeight = 26
    @ScaledMetric(relativeTo: .footnote) private var labelWidth = 56

    /// The Elite EXP's rail band colors (design.md allows these custom colors).
    private func band(for location: PowerBlockTable.Location) -> Color? {
        switch location {
        case .handleOnly: nil
        case .firstSlot, .slot(90): .black
        case .slot(30): .white
        case .slot(40): .purple
        case .slot(50): .green
        case .slot(60): .yellow
        case .slot(70): .blue
        case .slot(80): .red
        case .slot: nil
        }
    }

    var body: some View {
        let setup = PowerBlockTable.setup(for: weight)
        let state = PowerBlockTable.diagramState(for: weight)
        let pinIndex = state?.selectedIndex ?? 0
        VStack(spacing: 12) {
            ZStack(alignment: .topLeading) {
                // Leading-aligned, so labels, rails and the pin share one origin whatever trails a row.
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(PowerBlockTable.locations.indices, id: \.self) { index in
                        let location = PowerBlockTable.locations[index]
                        railRow(
                            location, index: index,
                            lifted: state.map { $0.lifted.contains(location) } ?? (index == 0),
                            adders: state?.adders ?? 0)
                    }
                }
                if state?.hasPin ?? false {
                    pin
                        .offset(x: labelWidth + 8, y: CGFloat(pinIndex) * rowHeight)
                        // Under Reduce Motion a new identity cross-fades instead of sliding.
                        .id(reduceMotion ? pinIndex : 0)
                        .transition(.opacity)
                }
            }
            .animation(animation, value: weight)
            .accessibilityHidden(true)
            Text(setup?.line ?? "")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("diagram.text")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(setup?.line ?? "")
        .accessibilityIdentifier("diagram.view")
    }

    private var animation: Animation {
        reduceMotion ? .easeInOut(duration: 0.25) : .spring(duration: 0.4, bounce: 0.25)
    }

    private func railRow(
        _ location: PowerBlockTable.Location, index: Int, lifted: Bool, adders: Int
    ) -> some View {
        HStack(spacing: 8) {
            Text(location.label ?? "")
                .font(.footnote)
                .monospacedDigit()
                .frame(width: labelWidth, alignment: .trailing)
            ZStack {
                Capsule().fill(Color.secondary.opacity(0.35)).frame(height: 6)
                if let band = band(for: location) {
                    Capsule().fill(band).frame(width: 36, height: 8)
                        .overlay(Capsule().stroke(Color.primary, lineWidth: 1))
                }
            }
            .frame(width: 120)
            if index == 0 {
                HStack(spacing: 6) {
                    ForEach(0..<2, id: \.self) { adder($0 < adders) }
                }
            } else if location == .firstSlot {
                Text("first slot").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .frame(height: rowHeight)
        .opacity(lifted ? 1 : 0.3)
    }

    /// A circle on the handle: filled when installed, outlined when not.
    private func adder(_ installed: Bool) -> some View {
        Circle()
            .stroke(Color.primary, lineWidth: 1.5)
            .frame(width: rowHeight * 0.7, height: rowHeight * 0.7)
            .overlay {
                Circle().fill(Color.primary)
                    .scaleEffect(installed || reduceMotion ? 1 : 0.2)
                    .opacity(installed ? 1 : 0)
            }
    }

    /// The magnetic pin, a ring on the target rail.
    private var pin: some View {
        Circle()
            .fill(Color.accentColor)
            .overlay(Circle().stroke(Color.primary, lineWidth: 1.5))
            .frame(width: rowHeight * 0.8, height: rowHeight * 0.8)
            .frame(width: 120, height: rowHeight)
    }
}
