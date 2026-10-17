// Renders the AngelTime app icon (a tomato-red squircle with a timer ring and a halo) as a
// 1024×1024 PNG.
//
//   swift scripts/make_icon.swift <output.png>

import AppKit

let size = 1024
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

guard let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("Could not create a drawing context") }

// macOS icon grid: an 824pt squircle centered in the 1024 canvas.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

// Drop shadow under the tile.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.35))
ctx.addPath(tilePath)
ctx.setFillColor(rgb(0xBA4949))
ctx.fillPath()
ctx.restoreGState()

// Tile gradient.
ctx.saveGState()
ctx.addPath(tilePath)
ctx.clip()
let gradient = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
    colors: [rgb(0xE06A5C), rgb(0xBA4949), rgb(0x963636)] as CFArray,
    locations: [0, 0.55, 1]
)!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
ctx.restoreGState()

// Timer ring: faint full track plus a bright 75% progress arc starting at 12 o'clock.
let center = CGPoint(x: 512, y: 462)
let radius: CGFloat = 238
ctx.setLineCap(.round)
ctx.setLineWidth(58)
ctx.setStrokeColor(rgb(0xFFFFFF, 0.28))
ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.strokePath()

ctx.setStrokeColor(rgb(0xFFFFFF))
ctx.addArc(center: center, radius: radius, startAngle: .pi / 2, endAngle: .pi / 2 - .pi * 1.5, clockwise: true)
ctx.strokePath()

// Clock hand + hub.
ctx.setLineWidth(34)
ctx.move(to: center)
ctx.addLine(to: CGPoint(x: center.x, y: center.y + 138))
ctx.strokePath()
ctx.setFillColor(rgb(0xFFFFFF))
ctx.fillEllipse(in: CGRect(x: center.x - 34, y: center.y - 34, width: 68, height: 68))

// Halo.
let halo = CGRect(x: 512 - 190, y: 772, width: 380, height: 92)
ctx.setShadow(offset: .zero, blur: 24, color: rgb(0xFFE29A, 0.8))
ctx.setLineWidth(30)
ctx.setStrokeColor(rgb(0xF7D46B))
ctx.strokeEllipse(in: halo)

guard let image = ctx.makeImage(),
      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
    fatalError("Could not encode the PNG")
}
try png.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
