import AppKit
import CoreGraphics

// Генератор иконки «Триглав» для Cerberus DNS.
// Каждый размер отрисовывается из вектора заново, а не уменьшается из одного
// большого PNG: на 16 и 32 px пересчёт по сетке даёт заметно более чистые края.

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

// Сетка иконки macOS: скруглённая плитка занимает 824 из 1024 точек холста,
// радиус скругления — 185.4 от стороны плитки.
let tileRatio: CGFloat   = 824.0 / 1024.0
let cornerRatio: CGFloat = 185.4 / 824.0

// Геометрия глифа.
//
// Средняя голова выше боковых. Это не украшение: у сердца в центре верхней
// кромки впадина, и три одинаковые доли давали ровно такой силуэт. Подъём в
// центре ломает это прочтение и сразу читается как «три головы, средняя главная».
struct Head { let x: CGFloat; let y: CGFloat; let r: CGFloat }
let heads = [
    Head(x: 152, y: 178, r: 50),   // левая
    Head(x: 256, y: 158, r: 60),   // средняя, выше и крупнее
    Head(x: 360, y: 178, r: 50)    // правая
]

// Корпус — геральдический щит: прямые плечи, затем схождение в остриё.
// Края щита совпадают с крайними точками боковых голов (152 ± 50).
// Иначе прямая верхняя кромка выступала за окружности и по краям
// торчали квадратные «плечики».
let shieldTop: CGFloat = 178
let shieldLeft: CGFloat = 102
let shieldRight: CGFloat = 410
let shieldTip: CGFloat = 432

let glyphBounds = CGRect(x: shieldLeft, y: 158 - 60,
                         width: shieldRight - shieldLeft,
                         height: shieldTip - (158 - 60))

func addGlyph(_ ctx: CGContext, fitInto target: CGRect) {
    ctx.saveGState()
    let s = target.width / glyphBounds.width
    ctx.translateBy(x: target.minX, y: target.minY)
    ctx.scaleBy(x: s, y: s)
    ctx.translateBy(x: -glyphBounds.minX, y: -glyphBounds.minY)

    let body = CGMutablePath()
    body.move(to: CGPoint(x: shieldLeft, y: shieldTop))
    body.addLine(to: CGPoint(x: shieldRight, y: shieldTop))
    body.addLine(to: CGPoint(x: shieldRight, y: 268))
    body.addCurve(to: CGPoint(x: 256, y: shieldTip),
                  control1: CGPoint(x: shieldRight, y: 346),
                  control2: CGPoint(x: 358, y: 394))
    body.addCurve(to: CGPoint(x: shieldLeft, y: 268),
                  control1: CGPoint(x: 154, y: 394),
                  control2: CGPoint(x: shieldLeft, y: 346))
    body.closeSubpath()
    ctx.addPath(body)
    ctx.fillPath()

    // Головы заливаются отдельными вызовами: в одном пути противоположная
    // намотка подконтуров пробила бы в пересечениях дыры.
    for h in heads {
        ctx.addEllipse(in: CGRect(x: h.x - h.r, y: h.y - h.r, width: h.r * 2, height: h.r * 2))
        ctx.fillPath()
    }
    ctx.restoreGState()
}

func render(size: Int) -> Data? {
    let S = CGFloat(size)
    guard let ctx = CGContext(data: nil,
                              width: size, height: size,
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }

    // Переворачиваем ось Y, чтобы координаты совпадали с SVG-исходником.
    ctx.translateBy(x: 0, y: S)
    ctx.scaleBy(x: 1, y: -1)
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    let inset = S * (1 - tileRatio) / 2
    let tile = CGRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2)
    let radius = tile.width * cornerRatio
    let tilePath = CGPath(roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Мягкая тень под плиткой — как у системных иконок.
    if size >= 64 {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -S * 0.012),
                      blur: S * 0.03,
                      color: NSColor(calibratedWhite: 0, alpha: 0.34).cgColor)
        ctx.addPath(tilePath)
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fillPath()
        ctx.restoreGState()
    }

    // Базальтовая плитка с лёгким градиентом сверху вниз.
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let colors = [
        NSColor(srgbRed: 0.149, green: 0.161, blue: 0.180, alpha: 1).cgColor, // #26292E
        NSColor(srgbRed: 0.102, green: 0.114, blue: 0.129, alpha: 1).cgColor  // #1A1D21
    ] as CFArray
    if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                             colors: colors, locations: [0, 1]) {
        ctx.drawLinearGradient(grad,
                               start: CGPoint(x: tile.minX, y: tile.minY),
                               end: CGPoint(x: tile.maxX, y: tile.maxY),
                               options: [])
    }
    ctx.restoreGState()

    // Тонкий блик по верхней кромке — читается начиная со 128 px.
    if size >= 128 {
        ctx.saveGState()
        ctx.addPath(tilePath)
        ctx.clip()
        ctx.setFillColor(NSColor(calibratedWhite: 1, alpha: 0.055).cgColor)
        ctx.fill(CGRect(x: tile.minX, y: tile.minY, width: tile.width, height: S * 0.0018 + 1))
        ctx.restoreGState()
    }

    // Глиф вписывается по своим настоящим границам, а не по холсту 512×512:
    // иначе пустые поля исходника съедали часть плитки и знак терялся.
    // На мелких размерах даём чуть больше места — тонкие детали там всё равно
    // теряются, и более плотный знак читается лучше.
    let widthRatio: CGFloat = size <= 32 ? 0.70 : 0.64
    let gw = tile.width * widthRatio
    let gh = gw * glyphBounds.height / glyphBounds.width
    let glyphRect = CGRect(x: tile.midX - gw / 2, y: tile.midY - gh / 2, width: gw, height: gh)
    ctx.setFillColor(NSColor(srgbRed: 0.929, green: 0.933, blue: 0.914, alpha: 1).cgColor) // #EDEEE9
    addGlyph(ctx, fitInto: glyphRect)

    guard let image = ctx.makeImage() else { return nil }
    let rep = NSBitmapImageRep(cgImage: image)
    return rep.representation(using: .png, properties: [:])
}

// Полный набор представлений, которых ждёт iconutil.
let variants: [(String, Int)] = [
    ("icon_16x16.png", 16),      ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),      ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),   ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),   ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),   ("icon_512x512@2x.png", 1024)
]

var failed = false
for (name, px) in variants {
    guard let data = render(size: px) else {
        FileHandle.standardError.write("не удалось отрисовать \(name)\n".data(using: .utf8)!)
        failed = true
        continue
    }
    try? data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
    print("  \(name)  \(px)×\(px)")
}
exit(failed ? 1 : 0)
