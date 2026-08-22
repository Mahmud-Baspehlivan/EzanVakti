import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

// Uygulama ikonu adaylarini 1024x1024 PNG olarak uretir.
//
//   swiftc -O EzanVakti/Features/Qibla/KaabaGlyph.swift Tools/icon/main.swift -o /tmp/icon
//   /tmp/icon <cikti-klasoru>
//
// Olculer bilerek orana bagli: mutlak punto verilirse gorunum kucuk boyutta
// render edilince tasiyor ve karsilastirma yaniltici oluyor.

private let navy = Color(red: 0.06, green: 0.08, blue: 0.20)
private let navyLow = Color(red: 0.14, green: 0.16, blue: 0.33)
private let goldLight = Color(red: 0.97, green: 0.88, blue: 0.58)
private let gold = Color(red: 0.86, green: 0.68, blue: 0.30)

struct IconKaabaLight: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Color(red: 0.98, green: 0.96, blue: 0.91),
                                        Color(red: 0.92, green: 0.88, blue: 0.79)],
                               startPoint: .top, endPoint: .bottom)
                KaabaGlyph()
                    .frame(width: geo.size.width * 0.51, height: geo.size.height * 0.51)
            }
        }
    }
}

struct IconKaabaDark: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [navy, navyLow], startPoint: .top, endPoint: .bottom)
                KaabaGlyph(stone: goldLight, trim: navyLow)
                    .frame(width: geo.size.width * 0.51, height: geo.size.height * 0.51)
            }
        }
    }
}

/// İki dairenin farkı; `subtracting` hilalin içini oyuyor.
struct Crescent: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var outer = Path()
        outer.addArc(center: c, radius: r, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
        var inner = Path()
        inner.addArc(center: CGPoint(x: c.x + r * 0.42, y: c.y - r * 0.10), radius: r * 0.86,
                     startAngle: .zero, endAngle: .degrees(360), clockwise: false)
        return outer.subtracting(inner)
    }
}

struct IconCrescent: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [navy, navyLow], startPoint: .top, endPoint: .bottom)
                Crescent()
                    .fill(LinearGradient(colors: [goldLight, gold],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: geo.size.width * 0.55, height: geo.size.height * 0.55)
                    .rotationEffect(.degrees(-20))
            }
        }
    }
}

struct MosqueSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: rect.minX + w * 0.16, y: rect.minY + h * 0.72))
        p.addCurve(to: CGPoint(x: rect.minX + w * 0.84, y: rect.minY + h * 0.72),
                   control1: CGPoint(x: rect.minX + w * 0.16, y: rect.minY + h * 0.16),
                   control2: CGPoint(x: rect.minX + w * 0.84, y: rect.minY + h * 0.16))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.84, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.16, y: rect.maxY))
        p.closeSubpath()
        p.addEllipse(in: CGRect(x: rect.midX - w * 0.035, y: rect.minY, width: w * 0.07, height: w * 0.07))
        for x in [0.02, 0.91] {
            p.addRoundedRect(in: CGRect(x: rect.minX + w * x, y: rect.minY + h * 0.30,
                                        width: w * 0.075, height: h * 0.70),
                             cornerSize: CGSize(width: w * 0.037, height: w * 0.037))
            p.move(to: CGPoint(x: rect.minX + w * (x + 0.037), y: rect.minY + h * 0.30))
            p.addLine(to: CGPoint(x: rect.minX + w * (x - 0.005), y: rect.minY + h * 0.20))
            p.addLine(to: CGPoint(x: rect.minX + w * (x + 0.079), y: rect.minY + h * 0.20))
            p.closeSubpath()
        }
        return p
    }
}

struct IconMosque: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Color(red: 0.06, green: 0.09, blue: 0.22),
                                        Color(red: 0.16, green: 0.13, blue: 0.30)],
                               startPoint: .top, endPoint: .bottom)
                MosqueSilhouette()
                    .fill(LinearGradient(colors: [goldLight, gold], startPoint: .top, endPoint: .bottom))
                    .frame(width: geo.size.width * 0.61, height: geo.size.height * 0.51)
                    .offset(y: geo.size.height * 0.03)
            }
        }
    }
}

/// Şeffaflık ve yuvarlatılmış köşe YOK: App Store alfa kanallı ikon kabul
/// etmiyor, köşeleri de sistem kendisi maskeliyor.
///
/// `ImageRenderer` her zaman alfa kanallı görüntü veriyor. Alfayı atmak için
/// `noneSkipLast` bir CGContext'e yeniden çizip PNG'yi `CGImageDestination` ile
/// yazıyoruz; `NSGraphicsContext` + alfasız `NSBitmapImageRep` yolu simsiyah
/// çıktı veriyor. `sips -g hasAlpha` ile doğrulanabilir.
@MainActor
func writeIcon(_ name: String, _ view: some View, to folder: URL) {
    let side = 1024
    let renderer = ImageRenderer(content: view.frame(width: CGFloat(side), height: CGFloat(side)))
    renderer.scale = 1

    guard let source = renderer.cgImage else {
        print("  \(name): render basarisiz"); return
    }
    guard let context = CGContext(
        data: nil, width: side, height: side,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { print("  \(name): baglam kurulamadi"); return }

    context.draw(source, in: CGRect(x: 0, y: 0, width: side, height: side))

    guard let flattened = context.makeImage() else {
        print("  \(name): duzlestirme basarisiz"); return
    }

    let url = folder.appendingPathComponent("\(name).png")
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else { print("  \(name): dosya acilamadi"); return }

    CGImageDestinationAddImage(destination, flattened, nil)
    guard CGImageDestinationFinalize(destination) else {
        print("  \(name): yazilamadi"); return
    }

    let size = (try? Data(contentsOf: url).count) ?? 0
    print("  \(url.lastPathComponent)  (\(size / 1024) KB)")
}

let folder = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "./icons")
try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
MainActor.assumeIsolated {
    print("1024x1024 opak PNG uretiliyor -> \(folder.path)")
    writeIcon("1-kabe-krem", IconKaabaLight(), to: folder)
    writeIcon("2-kabe-lacivert", IconKaabaDark(), to: folder)
    writeIcon("3-hilal", IconCrescent(), to: folder)
    writeIcon("4-kubbe-minare", IconMosque(), to: folder)
}
