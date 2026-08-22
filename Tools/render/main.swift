import AppKit
import SwiftUI

@MainActor
func render(_ name: String, _ view: some View, size: CGSize, scale: CGFloat = 2) {
    let renderer = ImageRenderer(content:
        ZStack { Color(red: 0.07, green: 0.09, blue: 0.20); view }
            .frame(width: size.width, height: size.height))
    renderer.scale = scale
    guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        print("render basarisiz: \(name)"); return
    }
    try? png.write(to: URL(fileURLWithPath: "/tmp/render-\(name).png"))
    print("yazildi: /tmp/render-\(name).png")
}

MainActor.assumeIsolated {
    // Gercek boyutlarda okunabilirlik testi
    render("glyph-sizes",
        HStack(spacing: 16) {
            ForEach([14, 18, 21, 28, 44], id: \.self) { s in
                ZStack {
                    Circle().fill(Color(red: 0.96, green: 0.94, blue: 0.88))
                        .frame(width: CGFloat(s) * 1.8, height: CGFloat(s) * 1.8)
                    KaabaGlyph().frame(width: CGFloat(s), height: CGFloat(s))
                }
                .frame(width: CGFloat(s) * 1.8, height: CGFloat(s) * 1.8)
            }
        },
        size: CGSize(width: 340, height: 100), scale: 3)

    render("glyph-big", KaabaGlyph().frame(width: 180, height: 180),
           size: CGSize(width: 220, height: 220))

    render("dial-north", QiblaDial(qiblaDirection: 151.62, heading: 0, isAligned: false),
           size: CGSize(width: 320, height: 320))
    render("dial-aligned", QiblaDial(qiblaDirection: 151.62, heading: 151.62, isAligned: true),
           size: CGSize(width: 320, height: 320))
}
