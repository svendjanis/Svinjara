import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// The icon is the game in one picture: a concrete circle, five little goals on the line in
// five colours, and a ball. Generated rather than drawn by hand, for the same reason the kits
// are — it is a recipe, so it can be regenerated at any size.

// An explicit opaque 8-bit context at exactly 1024 x 1024: an iOS app icon may not carry an
// alpha channel, and NSImage's lockFocus would render at the display's 2x backing scale.
let side: CGFloat = 1024
guard let cg = CGContext(data: nil,
                         width: Int(side), height: Int(side),
                         bitsPerComponent: 8, bytesPerRow: 0,
                         space: CGColorSpace(name: CGColorSpace.sRGB)!,
                         bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { exit(1) }

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

// Concrete ground, with a bit of noise so it does not read as flat vinyl.
cg.setFillColor(rgb(0x47484A))
cg.fill(CGRect(x: 0, y: 0, width: side, height: side))

var seed: UInt64 = 20260912
func random() -> Double {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return Double((seed >> 11)) / Double(UInt64(1) << 53)
}

for _ in 0..<2600 {
    let r = CGFloat(random() * 5 + 1)
    cg.setFillColor(CGColor(gray: CGFloat(random() < 0.6 ? 0.30 : 0.62),
                            alpha: CGFloat(random() * 0.35 + 0.1)))
    cg.fillEllipse(in: CGRect(x: CGFloat(random()) * side, y: CGFloat(random()) * side,
                              width: r, height: r))
}
for _ in 0..<16 {
    cg.setFillColor(CGColor(gray: CGFloat(random() < 0.5 ? 0.28 : 0.60),
                            alpha: 0.06))
    let r = CGFloat(random() * 260 + 80)
    cg.fillEllipse(in: CGRect(x: CGFloat(random()) * side - r, y: CGFloat(random()) * side - r,
                              width: r * 2, height: r * 2))
}

let centre = CGPoint(x: side / 2, y: side / 2)
let radius = side * 0.355
let lineWidth = side * 0.032

// The white line.
cg.setStrokeColor(CGColor(red: 0.88, green: 0.88, blue: 0.855, alpha: 1))
cg.setLineWidth(lineWidth)
cg.strokeEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius,
                            width: radius * 2, height: radius * 2))

// Five goals on it, in five kits.
let colours: [UInt32] = [0xFFDF00, 0xFF3B30, 0x1B62A5, 0x009739, 0xFF6200]
let half: CGFloat = 0.20
cg.setLineCap(.butt)
for index in 0..<5 {
    let bearing = -CGFloat.pi / 2 + CGFloat(index) * (2 * .pi / 5)
    cg.setStrokeColor(rgb(colours[index]))
    cg.setLineWidth(lineWidth * 2.1)
    cg.addArc(center: centre, radius: radius,
              startAngle: bearing - half, endAngle: bearing + half, clockwise: false)
    cg.strokePath()

    for side1 in [-half, half] {
        let post = CGPoint(x: centre.x + cos(bearing + side1) * radius,
                           y: centre.y + sin(bearing + side1) * radius)
        let pr = side * 0.017
        cg.setFillColor(CGColor(gray: 0.92, alpha: 1))
        cg.fillEllipse(in: CGRect(x: post.x - pr, y: post.y - pr, width: pr * 2, height: pr * 2))
    }
}

// The ball, slightly off the spot so it reads as in play.
let ballR = side * 0.075
let ballCentre = CGPoint(x: centre.x + side * 0.035, y: centre.y - side * 0.02)
cg.setFillColor(CGColor(gray: 0, alpha: 0.3))
cg.fillEllipse(in: CGRect(x: ballCentre.x - ballR * 0.92, y: ballCentre.y - ballR * 1.1,
                          width: ballR * 1.9, height: ballR * 1.9))
cg.setFillColor(CGColor(gray: 0.97, alpha: 1))
cg.fillEllipse(in: CGRect(x: ballCentre.x - ballR, y: ballCentre.y - ballR,
                          width: ballR * 2, height: ballR * 2))
cg.saveGState()
cg.addEllipse(in: CGRect(x: ballCentre.x - ballR, y: ballCentre.y - ballR,
                         width: ballR * 2, height: ballR * 2))
cg.clip()
cg.setFillColor(CGColor(gray: 0.12, alpha: 1))
let patch = ballR * 0.62
cg.fillEllipse(in: CGRect(x: ballCentre.x - patch / 2, y: ballCentre.y - patch / 2,
                          width: patch, height: patch))
for step in 0..<5 {
    let a = CGFloat(step) * (2 * .pi / 5) + 0.4
    let small = ballR * 0.44
    cg.fillEllipse(in: CGRect(x: ballCentre.x + cos(a) * ballR * 0.78 - small / 2,
                              y: ballCentre.y + sin(a) * ballR * 0.78 - small / 2,
                              width: small, height: small))
}
cg.restoreGState()

guard let image = cg.makeImage() else { exit(1) }
let url = URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL
guard let destination = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { exit(1) }
print("wrote \(CommandLine.arguments[1]) at \(image.width)x\(image.height)")
