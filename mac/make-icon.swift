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
let ink = NSColor(red: 0x3a / 255, green: 0x39 / 255, blue: 0x36 / 255, alpha: 1).cgColor

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

ctx.setStrokeColor(ink)
ctx.setLineWidth(28)
ctx.setLineJoin(.round)
ctx.setLineCap(.round)

let mx: CGFloat = 512, my: CGFloat = 224

func polygon(_ points: [(CGFloat, CGFloat)]) {
  ctx.move(to: CGPoint(x: points[0].0, y: points[0].1))
  for p in points.dropFirst() { ctx.addLine(to: CGPoint(x: p.0, y: p.1)) }
  ctx.closePath()
}

func rotated(_ degrees: CGFloat, _ draw: () -> Void) {
  ctx.saveGState()
  ctx.translateBy(x: mx, y: my)
  ctx.rotate(by: degrees * .pi / 180)
  ctx.translateBy(x: -mx, y: -my)
  draw()
  ctx.restoreGState()
}

rotated(-8) {
  ctx.setFillColor(paper)
  ctx.addRect(CGRect(x: 232, y: 214, width: 560, height: 640))
  ctx.drawPath(using: .fillStroke)
}

rotated(3) {
  ctx.setFillColor(paper)
  polygon([(232, 214), (792, 214), (792, 724), (662, 854), (232, 854)])
  ctx.drawPath(using: .fillStroke)
  ctx.setFillColor(ink)
  polygon([(792, 724), (662, 724), (662, 854)])
  ctx.drawPath(using: .fillStroke)
}

ctx.setFillColor(ink)
ctx.fillEllipse(in: CGRect(x: mx - 86, y: my - 86, width: 172, height: 172))

ctx.setStrokeColor(paper)
ctx.setLineWidth(18)
let steps = 32
for i in 0...steps {
  let a = (200 + 55 * CGFloat(i) / CGFloat(steps)) * .pi / 180
  let p = CGPoint(x: mx + 58 * cos(a), y: my + 58 * sin(a))
  if i == 0 { ctx.move(to: p) } else { ctx.addLine(to: p) }
}
ctx.strokePath()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: out)
