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

let inset = square ? 100 * s : 0
let tile = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
ctx.saveGState()
if square { ctx.setShadow(offset: CGSize(width: 0, height: -8 * s), blur: 22 * s, color: NSColor.black.withAlphaComponent(0.28).cgColor) }
ctx.setFillColor(NSColor(red: 0.20, green: 0.47, blue: 0.96, alpha: 1).cgColor)
ctx.fill(tile)
ctx.restoreGState()

let k = tile.width / 1024
func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: tile.minX + x * k, y: tile.minY + y * k) }
ctx.setStrokeColor(NSColor.white.cgColor)
ctx.setLineWidth(110 * k)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.move(to: p(270, 520))
ctx.addLine(to: p(445, 345))
ctx.addLine(to: p(770, 690))
ctx.strokePath()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: out)
