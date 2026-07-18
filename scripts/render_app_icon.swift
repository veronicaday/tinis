import AppKit

let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon.png")
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: 1024,
    height: 1024,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fatalError("Could not create a drawing context")
}

let backgroundColors = [
    NSColor(calibratedRed: 0.0, green: 0.102, blue: 0.075, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.024, green: 0.235, blue: 0.180, alpha: 1).cgColor
] as CFArray
let background = CGGradient(colorsSpace: colorSpace, colors: backgroundColors, locations: [0, 1])!
context.drawLinearGradient(
    background,
    start: CGPoint(x: 512, y: 1024),
    end: CGPoint(x: 512, y: 0),
    options: []
)

let gold = NSColor(calibratedRed: 0.788, green: 0.682, blue: 0.447, alpha: 1)
let moss = NSColor(calibratedRed: 0.443, green: 0.506, blue: 0.333, alpha: 1)
let cream = NSColor(calibratedRed: 0.973, green: 0.953, blue: 0.925, alpha: 1)

context.saveGState()
context.setShadow(offset: .zero, blur: 34, color: gold.withAlphaComponent(0.22).cgColor)
context.setStrokeColor(gold.cgColor)
context.setLineWidth(13)
context.strokeEllipse(in: CGRect(x: 282, y: 282, width: 460, height: 460))
context.restoreGState()

context.setFillColor(moss.cgColor)
context.fillEllipse(in: CGRect(x: 387, y: 417, width: 150, height: 150))

context.setStrokeColor(cream.withAlphaComponent(0.9).cgColor)
context.setLineWidth(11)
context.strokeEllipse(in: CGRect(x: 442, y: 472, width: 40, height: 40))

context.saveGState()
context.translateBy(x: 612, y: 632)
context.rotate(by: -.pi * 38 / 180)
context.setFillColor(gold.cgColor)
context.fill(CGRect(x: -10, y: -225, width: 20, height: 450))
context.restoreGState()

guard
    let cgImage = context.makeImage(),
    let pngData = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
else {
    fatalError("Could not encode the app icon")
}

try pngData.write(to: outputURL, options: .atomic)
