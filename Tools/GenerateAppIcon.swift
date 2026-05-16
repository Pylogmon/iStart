import AppKit
import CoreGraphics
import Foundation

struct IconImage {
    let filename: String
    let pixels: Int
}

let outputDirectory = URL(fileURLWithPath: "iStart/Assets.xcassets/AppIcon.appiconset")

let images: [IconImage] = [
    .init(filename: "AppIcon-16.png", pixels: 16),
    .init(filename: "AppIcon-16@2x.png", pixels: 32),
    .init(filename: "AppIcon-32.png", pixels: 32),
    .init(filename: "AppIcon-32@2x.png", pixels: 64),
    .init(filename: "AppIcon-128.png", pixels: 128),
    .init(filename: "AppIcon-128@2x.png", pixels: 256),
    .init(filename: "AppIcon-256.png", pixels: 256),
    .init(filename: "AppIcon-256@2x.png", pixels: 512),
    .init(filename: "AppIcon-512.png", pixels: 512),
    .init(filename: "AppIcon-512@2x.png", pixels: 1024)
]

func color(_ hex: UInt32, alpha: CGFloat = 1.0) -> CGColor {
    let red = CGFloat((hex >> 16) & 0xff) / 255.0
    let green = CGFloat((hex >> 8) & 0xff) / 255.0
    let blue = CGFloat(hex & 0xff) / 255.0
    return CGColor(red: red, green: green, blue: blue, alpha: alpha)
}

func path(rounded rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawLinearGradient(
    in context: CGContext,
    rect: CGRect,
    colors: [CGColor],
    locations: [CGFloat],
    start: CGPoint,
    end: CGPoint
) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) else {
        return
    }
    context.saveGState()
    context.clip(to: rect)
    context.drawLinearGradient(gradient, start: start, end: end, options: [])
    context.restoreGState()
}

func drawRoundedGradient(
    in context: CGContext,
    rect: CGRect,
    radius: CGFloat,
    colors: [CGColor],
    locations: [CGFloat],
    start: CGPoint,
    end: CGPoint
) {
    context.saveGState()
    context.addPath(path(rounded: rect, radius: radius))
    context.clip()
    drawLinearGradient(in: context, rect: rect, colors: colors, locations: locations, start: start, end: end)
    context.restoreGState()
}

func drawShadowedRoundedRect(
    in context: CGContext,
    rect: CGRect,
    radius: CGFloat,
    fill: CGColor,
    shadowColor: CGColor,
    shadowBlur: CGFloat,
    shadowOffset: CGSize
) {
    context.saveGState()
    context.setShadow(offset: shadowOffset, blur: shadowBlur, color: shadowColor)
    context.addPath(path(rounded: rect, radius: radius))
    context.setFillColor(fill)
    context.fillPath()
    context.restoreGState()
}

func drawIcon(pixels: Int) -> NSBitmapImageRep {
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let context = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext
    else {
        fatalError("Unable to create drawing context")
    }

    bitmap.size = NSSize(width: pixels, height: pixels)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    let scale = CGFloat(pixels) / 1024.0
    func s(_ value: CGFloat) -> CGFloat { value * scale }
    func r(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(x: s(x), y: s(y), width: s(width), height: s(height))
    }

    let canvas = CGRect(x: 0, y: 0, width: pixels, height: pixels)
    context.clear(canvas)

    let plate = r(88, 88, 848, 848)
    drawShadowedRoundedRect(
        in: context,
        rect: plate,
        radius: s(196),
        fill: color(0x123b7a),
        shadowColor: color(0x00102a, alpha: 0.34),
        shadowBlur: s(34),
        shadowOffset: CGSize(width: 0, height: -s(14))
    )

    context.saveGState()
    context.addPath(path(rounded: plate, radius: s(196)))
    context.clip()
    drawLinearGradient(
        in: context,
        rect: plate,
        colors: [color(0x72d9ff), color(0x2c8dff), color(0x17459d)],
        locations: [0.0, 0.46, 1.0],
        start: CGPoint(x: plate.minX + s(70), y: plate.maxY - s(42)),
        end: CGPoint(x: plate.maxX - s(86), y: plate.minY + s(70))
    )

    let glowSpace = CGColorSpaceCreateDeviceRGB()
    if let glow = CGGradient(
        colorsSpace: glowSpace,
        colors: [color(0xffffff, alpha: 0.34), color(0xffffff, alpha: 0.0)] as CFArray,
        locations: [0, 1]
    ) {
        context.drawRadialGradient(
            glow,
            startCenter: CGPoint(x: s(310), y: s(770)),
            startRadius: 0,
            endCenter: CGPoint(x: s(310), y: s(770)),
            endRadius: s(420),
            options: []
        )
    }
    context.restoreGState()

    let menu = r(266, 266, 492, 492)
    drawShadowedRoundedRect(
        in: context,
        rect: menu,
        radius: s(118),
        fill: color(0xffffff, alpha: 0.2),
        shadowColor: color(0x00102a, alpha: 0.3),
        shadowBlur: s(34),
        shadowOffset: CGSize(width: 0, height: -s(10))
    )

    context.saveGState()
    context.addPath(path(rounded: menu, radius: s(118)))
    context.clip()
    drawLinearGradient(
        in: context,
        rect: menu,
        colors: [color(0xffffff, alpha: 0.9), color(0xd7f5ff, alpha: 0.78)],
        locations: [0, 1],
        start: CGPoint(x: menu.minX, y: menu.maxY),
        end: CGPoint(x: menu.maxX, y: menu.minY)
    )
    context.restoreGState()

    let paneGap = s(30)
    let paneSize = (menu.width - s(136) - paneGap) / 2
    let paneGridWidth = paneSize * 2 + paneGap
    let paneStartX = menu.midX - paneGridWidth / 2
    let paneStartY = menu.minY + s(68)

    for row in 0..<2 {
        for column in 0..<2 {
            let rect = CGRect(
                x: paneStartX + CGFloat(column) * (paneSize + paneGap),
                y: paneStartY + CGFloat(row) * (paneSize + paneGap),
                width: paneSize,
                height: paneSize
            )
            drawRoundedGradient(
                in: context,
                rect: rect,
                radius: s(34),
                colors: [color(0x39ccff), color(0x1976ee)],
                locations: [0, 1],
                start: CGPoint(x: rect.minX, y: rect.maxY),
                end: CGPoint(x: rect.maxX, y: rect.minY)
            )
        }
    }

    context.saveGState()
    context.addPath(path(rounded: plate.insetBy(dx: s(10), dy: s(10)), radius: s(184)))
    context.setStrokeColor(color(0xffffff, alpha: 0.24))
    context.setLineWidth(s(8))
    context.strokePath()
    context.restoreGState()

    return bitmap
}

func writePNG(_ image: NSBitmapImageRep, to url: URL) throws {
    guard let png = image.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try png.write(to: url, options: .atomic)
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for image in images {
    let icon = drawIcon(pixels: image.pixels)
    try writePNG(icon, to: outputDirectory.appendingPathComponent(image.filename))
}
