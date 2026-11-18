import AppKit

let args = CommandLine.arguments
let size = CGFloat(Double(args.count > 1 ? args[1] : "1024") ?? 1024)
let out = URL(fileURLWithPath: args.count > 2 ? args[2] : "icon.png")
let square = args.count > 3 && args[3] == "square"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
let s = size / 1024

let paper = NSColor(red: 0xef / 255, green: 0xe8 / 255, blue: 0xd6 / 255, alpha: 1).cgColor
let ink = NSColor(red: 0x2b / 255, green: 0x2a / 255, blue: 0x28 / 255, alpha: 1).cgColor

let inset = square ? 100 * s : 0
let tile = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
ctx.saveGState()
if square { ctx.setShadow(offset: CGSize(width: 0, height: -8 * s), blur: 22 * s, color: NSColor.black.withAlphaComponent(0.28).cgColor) }
ctx.setFillColor(paper)
ctx.fill(tile)
ctx.restoreGState()

let k = tile.width / 1024
ctx.translateBy(x: tile.minX, y: tile.maxY)
ctx.scaleBy(x: k, y: -k)
ctx.translateBy(x: 512, y: 512)
ctx.scaleBy(x: 1.3, y: 1.3)
ctx.translateBy(x: -505, y: -500)
ctx.setStrokeColor(ink)
ctx.setFillColor(paper)
ctx.setLineWidth(14)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)

func line(_ points: [(CGFloat, CGFloat)], close: Bool = false) {
  ctx.move(to: CGPoint(x: points[0].0, y: points[0].1))
  for p in points.dropFirst() { ctx.addLine(to: CGPoint(x: p.0, y: p.1)) }
  if close { ctx.closePath() }
}

ctx.saveGState()
ctx.translateBy(x: 500, y: 490)
ctx.rotate(by: -8 * .pi / 180)
ctx.translateBy(x: -500, y: -500)
line([(300, 220), (600, 220), (700, 320), (700, 780), (300, 780)], close: true)
line([(600, 220), (600, 320), (700, 320)])
line([(360, 420), (620, 420)])
line([(360, 500), (620, 500)])
line([(360, 580), (500, 580)])
ctx.strokePath()
ctx.restoreGState()

ctx.translateBy(x: 690, y: 770)
ctx.rotate(by: .pi / 4)
line([(0, 0), (-96, -36), (-96, 36)], close: true)
ctx.addPath(CGPath(roundedRect: CGRect(x: -420, y: -36, width: 308, height: 72), cornerWidth: 14, cornerHeight: 14, transform: nil))
ctx.drawPath(using: .fillStroke)
line([(-24, 0), (-64, 0)])
ctx.strokePath()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: out)
