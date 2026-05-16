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

func drawTile(in context: CGContext, rect: CGRect, radius: CGFloat, colors: [CGColor]) {
    drawShadowedRoundedRect(
        in: context,
        rect: rect,
        radius: radius,
        fill: color(0xffffff, alpha: 0.16),
        shadowColor: color(0x0a1630, alpha: 0.16),
        shadowBlur: rect.width * 0.18,
        shadowOffset: CGSize(width: 0, height: rect.width * 0.08)
    )
    drawRoundedGradient(
        in: context,
        rect: rect,
        radius: radius,
        colors: colors,
        locations: [0, 1],
        start: CGPoint(x: rect.minX, y: rect.maxY),
        end: CGPoint(x: rect.maxX, y: rect.minY)
    )
    context.saveGState()
    context.addPath(path(rounded: rect.insetBy(dx: rect.width * 0.08, dy: rect.width * 0.08), radius: radius * 0.72))
    context.setStrokeColor(color(0xffffff, alpha: 0.22))
    context.setLineWidth(max(1, rect.width * 0.035))
    context.strokePath()
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

    let plate = r(78, 78, 868, 868)
    drawShadowedRoundedRect(
        in: context,
        rect: plate,
        radius: s(210),
        fill: color(0x123c7c),
        shadowColor: color(0x00102a, alpha: 0.34),
        shadowBlur: s(38),
        shadowOffset: CGSize(width: 0, height: -s(16))
    )

    context.saveGState()
    context.addPath(path(rounded: plate, radius: s(210)))
    context.clip()
    drawLinearGradient(
        in: context,
        rect: plate,
        colors: [color(0x8ee7ff), color(0x2f8eff), color(0x1842a2), color(0x0b215e)],
        locations: [0.0, 0.38, 0.72, 1.0],
        start: CGPoint(x: plate.minX + s(30), y: plate.maxY - s(20)),
        end: CGPoint(x: plate.maxX - s(70), y: plate.minY + s(50))
    )

    let glowSpace = CGColorSpaceCreateDeviceRGB()
    if let glow = CGGradient(
        colorsSpace: glowSpace,
        colors: [color(0xffffff, alpha: 0.42), color(0xffffff, alpha: 0.0)] as CFArray,
        locations: [0, 1]
    ) {
        context.drawRadialGradient(
            glow,
            startCenter: CGPoint(x: s(350), y: s(720)),
            startRadius: 0,
            endCenter: CGPoint(x: s(350), y: s(720)),
            endRadius: s(470),
            options: []
        )
    }
    context.restoreGState()

    let tilePalette: [[CGColor]] = [
        [color(0xff6b8a), color(0xffb84e)],
        [color(0x5df0c6), color(0x2fa9ff)],
        [color(0xf8ec68), color(0xff8a44)],
        [color(0xb990ff), color(0x4e68ff)],
        [color(0x6df07d), color(0x17a7a8)],
        [color(0xff83d8), color(0x8565ff)]
    ]
    let tileRects = [
        r(238, 682, 126, 126),
        r(449, 706, 104, 104),
        r(649, 642, 134, 134),
        r(210, 458, 110, 110),
        r(704, 430, 116, 116),
        r(492, 206, 126, 126)
    ]
    for (index, rect) in tileRects.enumerated() {
        drawTile(in: context, rect: rect, radius: s(28), colors: tilePalette[index])
    }

    let menu = r(292, 294, 440, 440)
    drawShadowedRoundedRect(
        in: context,
        rect: menu,
        radius: s(112),
        fill: color(0x0a1a42, alpha: 0.44),
        shadowColor: color(0x00102a, alpha: 0.38),
        shadowBlur: s(42),
        shadowOffset: CGSize(width: 0, height: -s(14))
    )
    drawRoundedGradient(
        in: context,
        rect: menu,
        radius: s(112),
        colors: [color(0xffffff, alpha: 0.92), color(0xccefff, alpha: 0.86), color(0x80c6ff, alpha: 0.82)],
        locations: [0, 0.44, 1],
        start: CGPoint(x: menu.minX, y: menu.maxY),
        end: CGPoint(x: menu.maxX, y: menu.minY)
    )

    context.saveGState()
    context.addPath(path(rounded: menu.insetBy(dx: s(22), dy: s(22)), radius: s(88)))
    context.setStrokeColor(color(0xffffff, alpha: 0.7))
    context.setLineWidth(s(9))
    context.strokePath()
    context.restoreGState()

    let paneGap = s(24)
    let paneSize = (menu.width - s(118) - paneGap) / 2
    let paneStartX = menu.minX + s(47)
    let paneStartY = menu.minY + s(47)
    let paneColors = [
        [color(0x36d6ff), color(0x2276ff)],
        [color(0x6be7ff), color(0x3fa8ff)],
        [color(0x2aa9ff), color(0x1556d1)],
        [color(0x77f3ff), color(0x2e83ff)]
    ]

    for row in 0..<2 {
        for column in 0..<2 {
            let index = row * 2 + column
            let rect = CGRect(
                x: paneStartX + CGFloat(column) * (paneSize + paneGap),
                y: paneStartY + CGFloat(row) * (paneSize + paneGap),
                width: paneSize,
                height: paneSize
            )
            drawRoundedGradient(
                in: context,
                rect: rect,
                radius: s(32),
                colors: paneColors[index],
                locations: [0, 1],
                start: CGPoint(x: rect.minX, y: rect.maxY),
                end: CGPoint(x: rect.maxX, y: rect.minY)
            )
        }
    }

    let lowerBar = r(376, 252, 272, 36)
    drawRoundedGradient(
        in: context,
        rect: lowerBar,
        radius: s(18),
        colors: [color(0xffffff, alpha: 0.62), color(0xb9e8ff, alpha: 0.42)],
        locations: [0, 1],
        start: CGPoint(x: lowerBar.minX, y: lowerBar.maxY),
        end: CGPoint(x: lowerBar.maxX, y: lowerBar.minY)
    )

    context.saveGState()
    context.addPath(path(rounded: plate.insetBy(dx: s(9), dy: s(9)), radius: s(198)))
    context.setStrokeColor(color(0xffffff, alpha: 0.24))
    context.setLineWidth(s(10))
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
