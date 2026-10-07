// Renders the app icon: a PowerBlock seen from the side, in the accent color.
// Writes 1024 × 1024 light, dark and tinted PNGs into AppIcon.appiconset.
// Run with `just icon` from the repository root.

import AppKit
import SwiftUI

let outputDirectory = URL(filePath: "App/Resources/Assets.xcassets/AppIcon.appiconset")

struct Palette {
    var backgroundTop: Color
    var backgroundBottom: Color
    var block: Color
}

// Both block colors are AccentColor's dark-appearance value, #E8710A: the light value,
// #B45309, is darkened for text contrast and looks brown at icon size.
// The tinted variant is grayscale: the system tints it by luminance.
let variants: [(file: String, palette: Palette)] = [
    (
        "AppIcon.png",
        Palette(
            backgroundTop: Color(hex: 0xFBF8F3), backgroundBottom: Color(hex: 0xEFE9E1),
            block: Color(hex: 0xE8710A))
    ),
    (
        "AppIcon-dark.png",
        Palette(
            backgroundTop: Color(hex: 0x232325), backgroundBottom: Color(hex: 0x0E0E10),
            block: Color(hex: 0xE8710A))
    ),
    (
        "AppIcon-tinted.png",
        Palette(
            backgroundTop: Color(hex: 0x000000), backgroundBottom: Color(hex: 0x000000),
            block: Color(hex: 0xE6E6E6))
    ),
]

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB, red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }
}

/// The dumbbell from its long side, as it stands on the floor: flat-topped end stacks of plates,
/// the nested plates' bars stepping down between them, and the handle across the top.
struct BlockIcon: View {
    var palette: Palette

    var body: some View {
        Canvas { context, size in
            let unit = size.width / 1024
            func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
                CGRect(x: x * unit, y: y * unit, width: w * unit, height: h * unit)
            }
            let block = GraphicsContext.Shading.color(palette.block)

            // Five nested U-shaped plates. Each plate's sides form the end stacks; its bottom
            // bar spans between them, so the inner plates' bars step up like stairs.
            let plates = 5
            let thickness = 30.0
            let gap = 10.0
            let left = 130.0
            let right = 1024 - left
            let bottom = 760.0
            let top = 280.0
            let stackWidth = Double(plates) * thickness + Double(plates - 1) * gap

            // The stacks are flat on top and bottom, with slightly rounded outer corners.
            var outline = Path()
            for (x, leading, trailing) in [(left, 12.0, 0.0), (right - stackWidth, 0.0, 12.0)] {
                outline.addPath(
                    UnevenRoundedRectangle(
                        topLeadingRadius: leading * unit, bottomLeadingRadius: leading * unit,
                        bottomTrailingRadius: trailing * unit, topTrailingRadius: trailing * unit
                    ).path(in: rect(x, top, stackWidth, bottom - top)))
            }
            outline.addRect(
                rect(left + stackWidth, top, right - left - 2 * stackWidth, bottom - top))
            var plateContext = context
            plateContext.clip(to: outline)
            for index in 0..<plates {
                let step = Double(index) * (thickness + gap)
                let barBottom = bottom - step
                for x in [left + step, right - step - thickness] {
                    plateContext.fill(Path(rect(x, top, thickness, barBottom - top)), with: block)
                }
                plateContext.fill(
                    Path(
                        rect(left + step, barBottom - thickness, right - left - 2 * step, thickness)
                    ), with: block)
            }

            // The handle: one straight bar across the top.
            let inner = left + stackWidth
            context.fill(Path(rect(inner, 380, 1024 - 2 * inner, 56)), with: block)
        }
        .background(
            LinearGradient(
                colors: [palette.backgroundTop, palette.backgroundBottom], startPoint: .top,
                endPoint: .bottom)
        )
        .frame(width: 1024, height: 1024)
    }
}

/// Renders the icon, then redraws it without an alpha channel, which App Store icons must not have.
@MainActor func writeIcon(_ palette: Palette, to url: URL) throws {
    let renderer = ImageRenderer(content: BlockIcon(palette: palette))
    renderer.scale = 1
    guard let image = renderer.cgImage,
        let context = CGContext(
            data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { throw CocoaError(.fileWriteUnknown) }
    context.draw(image, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    let png = NSBitmapImageRep(cgImage: context.makeImage()!).representation(
        using: .png, properties: [:])!
    try png.write(to: url)
}

try MainActor.assumeIsolated {
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    for variant in variants {
        try writeIcon(variant.palette, to: outputDirectory.appending(path: variant.file))
        print("wrote \(outputDirectory.appending(path: variant.file).relativePath)")
    }
}
