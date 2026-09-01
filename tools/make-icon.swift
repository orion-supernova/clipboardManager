import AppKit

// Mahmut Clipboard app icon.
// The product's visual signature is the strip of glass cards, so the icon is
// that strip seen as a stack: three rounded cards, front one crisp, the two
// behind it receding. Indigo because #5E5CE6 is the accent the panel uses.

let outDir = CommandLine.arguments[1]
/// Small sizes drop the back cards and the second text line — at 16pt they only
/// turn to mush, which is why Apple ships simplified art for the small slots.
let simple = CommandLine.arguments.count > 2 && CommandLine.arguments[2] == "simple"
let canvas: CGFloat = 1024

/// Apple's icon grid: the body is 824pt inside a 1024pt canvas.
let bodyInset: CGFloat = 88
let bodySide = canvas - bodyInset * 2

/// A superellipse, not a circular rounded rect — the corner continuity is the
/// difference between "a macOS icon" and "a rounded square".
func squircle(in rect: CGRect, n: CGFloat = 5.4, steps: Int = 720) -> NSBezierPath {
    let a = rect.width / 2, b = rect.height / 2
    let cx = rect.midX, cy = rect.midY
    let path = NSBezierPath()
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = cx + a * pow(abs(ct), 2 / n) * (ct < 0 ? -1 : 1)
        let y = cy + b * pow(abs(st), 2 / n) * (st < 0 ? -1 : 1)
        if i == 0 { path.move(to: NSPoint(x: x, y: y)) } else { path.line(to: NSPoint(x: x, y: y)) }
    }
    path.close()
    return path
}

func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: a)
}

let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
bitmap.size = NSSize(width: canvas, height: canvas)
NSGraphicsContext.saveGraphicsState()
let gctx = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.current = gctx
let ctx = gctx.cgContext
ctx.setShouldAntialias(true)

let body = CGRect(x: bodyInset, y: bodyInset, width: bodySide, height: bodySide)
let bodyPath = squircle(in: body)

// Drop shadow under the body, the way every macOS icon sits on its grid.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 34,
              color: rgb(0, 0, 0, 0.24).cgColor)
rgb(40, 30, 110).setFill()
bodyPath.fill()
ctx.restoreGState()

// Body gradient: lighter indigo at the top, deeper violet at the bottom.
ctx.saveGState()
bodyPath.addClip()
NSGradient(colors: [rgb(124, 118, 255), rgb(94, 92, 230), rgb(63, 48, 186)],
           atLocations: [0, 0.48, 1], colorSpace: .sRGB)!
    .draw(in: body, angle: -90)

// A soft sheen across the top third, so it reads as glass rather than flat fill.
NSGradient(colors: [rgb(255, 255, 255, 0.30), rgb(255, 255, 255, 0)], atLocations: [0, 1], colorSpace: .sRGB)!
    .draw(in: CGRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
ctx.restoreGState()

// The card stack.
struct Card { let dx: CGFloat; let dy: CGFloat; let scale: CGFloat; let alpha: CGFloat }
let cards = simple
    ? [Card(dx: 0, dy: 0, scale: 1.18, alpha: 1.00)]
    : [
        Card(dx: -78, dy:  76, scale: 0.86, alpha: 0.42),
        Card(dx: -30, dy:  28, scale: 0.93, alpha: 0.64),
        Card(dx:  32, dy: -32, scale: 1.00, alpha: 1.00),
    ]
let cardW: CGFloat = 486, cardH: CGFloat = 350, cardR: CGFloat = 60

ctx.saveGState()
bodyPath.addClip()
for card in cards {
    let w = cardW * card.scale, h = cardH * card.scale
    let rect = CGRect(x: body.midX - w / 2 + card.dx - (simple ? 0 : 6), y: body.midY - h / 2 + card.dy - (simple ? 0 : 20), width: w, height: h)
    let path = NSBezierPath(roundedRect: rect, xRadius: cardR * card.scale, yRadius: cardR * card.scale)
    ctx.saveGState()
    if card.alpha == 1 {
        ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 26, color: rgb(20, 10, 70, 0.45).cgColor)
    }
    rgb(255, 255, 255, card.alpha).setFill()
    path.fill()
    ctx.restoreGState()

    // Two text lines on the front card only — anything more turns to mush at 16px.
    if card.alpha == 1 {
        let lineFractions: [CGFloat] = simple ? [0.58] : [0.62, 0.40]
        for (index, frac) in lineFractions.enumerated() {
            let lw = w * frac
            let ly = rect.midY + (index == 0 ? 24 : -50)
            let line = NSBezierPath(roundedRect: CGRect(x: rect.minX + 56, y: ly, width: lw, height: 36),
                                    xRadius: 18, yRadius: 18)
            rgb(94, 92, 230, index == 0 ? 0.95 : 0.55).setFill()
            line.fill()
        }
    }
}
ctx.restoreGState()

// A hairline inner edge keeps the silhouette crisp against light wallpapers.
ctx.saveGState()
rgb(255, 255, 255, 0.22).setStroke()
bodyPath.lineWidth = 3
bodyPath.stroke()
ctx.restoreGState()

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("encode failed") }
let masterURL = URL(filePath: outDir).appending(path: simple ? "icon-simple-1024.png" : "icon-1024.png")
try! png.write(to: masterURL)
print("wrote \(masterURL.path)")
