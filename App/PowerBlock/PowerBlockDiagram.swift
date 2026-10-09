import SwiftUI

/// A side view of the PowerBlock stack set up for a weight: the handle and eight plate rails, the pin at its
/// rail, and the two adders on the handle. The weight is the only input; any change of it animates.
@MainActor
struct PowerBlockDiagram: View {
    let weight: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .footnote) private var rowHeight = 26
    @ScaledMetric(relativeTo: .footnote) private var labelWidth = 56

    /// One rail, top to bottom. The band colors copy the Elite EXP's rails (design.md allows these custom colors).
    @MainActor
    private struct Rail {
        let label: String?
        let band: Color?
        let location: PowerBlockTable.Location
    }

    private static let rails: [Rail] = [
        Rail(label: "Handle", band: nil, location: .handleOnly),
        Rail(label: nil, band: .black, location: .firstSlot),
        Rail(label: "30", band: .white, location: .slot(30)),
        Rail(label: "40", band: .purple, location: .slot(40)),
        Rail(label: "50", band: .green, location: .slot(50)),
        Rail(label: "60", band: .yellow, location: .slot(60)),
        Rail(label: "70", band: .blue, location: .slot(70)),
        Rail(label: "80", band: .red, location: .slot(80)),
        Rail(label: "90", band: .black, location: .slot(90)),
    ]

    var body: some View {
        let setup = PowerBlockTable.setup(for: weight)
        let pinIndex = Self.rails.firstIndex { $0.location == setup?.location } ?? 0
        VStack(spacing: 12) {
            ZStack(alignment: .topLeading) {
                // Leading-aligned, so labels, rails and the pin share one origin whatever trails a row.
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Self.rails.indices, id: \.self) { index in
                        railRow(
                            Self.rails[index], index: index, pinIndex: pinIndex,
                            adders: setup?.adders ?? 0)
                    }
                }
                if pinIndex > 0 {
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

    private func railRow(_ rail: Rail, index: Int, pinIndex: Int, adders: Int) -> some View {
        HStack(spacing: 8) {
            Text(rail.label ?? "")
                .font(.footnote)
                .monospacedDigit()
                .frame(width: labelWidth, alignment: .trailing)
            ZStack {
                Capsule().fill(Color.secondary.opacity(0.35)).frame(height: 6)
                if let band = rail.band {
                    Capsule().fill(band).frame(width: 36, height: 8)
                        .overlay(Capsule().stroke(Color.primary, lineWidth: 1))
                }
            }
            .frame(width: 120)
            if index == 0 {
                HStack(spacing: 6) {
                    ForEach(0..<2, id: \.self) { adder($0 < adders) }
                }
            } else if rail.label == nil {
                Text("first slot").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .frame(height: rowHeight)
        .opacity(index <= pinIndex ? 1 : 0.3)
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
