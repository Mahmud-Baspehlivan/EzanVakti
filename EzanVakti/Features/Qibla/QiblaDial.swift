import SwiftUI

/// Kadranda derece yazısı olup olmayacağı.
enum DegreeLabelStyle {
    case none
    /// 30° aralıklarla; ana yönler harf olarak kalıyor.
    case every30
    /// Yalnızca köşegenlerde (45°); daha az kalabalık.
    case every45
}

/// Pusula kadranı.
///
/// Çentikler, yön harfleri ve derece yazıları tek bir `Canvas` ile çiziliyor.
/// Önce her çentik ayrı bir `Rectangle` + `offset` + `rotationEffect` idi;
/// 72 çentik + harfler + derece yazıları ile karede 81 dönüşüm katmanı
/// hesaplanıyordu ve ölçümde render 2.14 ms/kare çıkıyordu. Pusula ekranı
/// yön güncellemesi hızında (saniyede onlarca kez) yeniden çizildiği için
/// bu gözle görülür takılmaya yol açıyordu. Canvas hepsini tek geçişte
/// çiziyor ve dönüşü doğrudan açı hesabına katıyor — iç içe rotationEffect
/// gerekmiyor.
struct QiblaDial: View {
    let qiblaDirection: Double
    let heading: Double
    let isAligned: Bool
    var degreeLabels: DegreeLabelStyle = .none

    private let radius: CGFloat = 148
    private var markerRadius: CGFloat { radius - 18 }

    private static let cardinals = ["K", "D", "G", "B"]

    var body: some View {
        ZStack {
            Circle().fill(.black.opacity(0.18))
            Circle().stroke(.white.opacity(0.14), lineWidth: 1)

            Canvas(rendersAsynchronously: false) { context, size in
                draw(in: &context, size: size)
            }

            // Tek görünüm olarak kaldı: bileşik bir çizim ve dönüşle birlikte
            // konum değiştiriyor, Canvas'a taşımanın kazancı yok.
            kaabaMarker
                .offset(y: -markerRadius)
                .rotationEffect(.degrees(qiblaDirection - heading))
        }
        .frame(width: radius * 2, height: radius * 2)
    }

    // MARK: - Çizim

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        for index in 0..<72 {
            let isCardinal = index % 18 == 0
            let isMajor = index % 6 == 0
            let length: CGFloat = isCardinal ? 14 : (isMajor ? 10 : 6)
            let width: CGFloat = isCardinal ? 2 : 1
            let opacity = isCardinal ? 0.85 : (isMajor ? 0.5 : 0.28)

            // Dönüş açıya katılıyor; kadranı ayrıca döndürmeye gerek kalmıyor.
            let angle = Double(index) * 5 - heading - 90
            let inner = radius - 8 - length / 2
            let outer = radius - 8 + length / 2

            var path = Path()
            path.move(to: point(center, inner, angle))
            path.addLine(to: point(center, outer, angle))
            context.stroke(path, with: .color(.white.opacity(opacity)), lineWidth: width)
        }

        for (index, letter) in Self.cardinals.enumerated() {
            let angle = Double(index) * 90 - heading - 90
            // Canvas'ta metin dik çiziliyor; harfin baş aşağı kalması sorunu
            // (Türkçe "G" sorunu) burada kendiliğinden yok.
            context.draw(
                Text(letter)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(index == 0 ? 0.9 : 0.55)),
                at: point(center, radius - 32, angle)
            )
        }

        guard let step = degreeStep else { return }
        for degree in stride(from: 0, to: 360, by: step) where degree % 90 != 0 {
            let angle = Double(degree) - heading - 90
            context.draw(
                Text("\(degree)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.38)),
                at: point(center, radius - 32, angle)
            )
        }
    }

    private var degreeStep: Int? {
        switch degreeLabels {
        case .none:    return nil
        case .every30: return 30
        case .every45: return 45
        }
    }

    private func point(_ center: CGPoint, _ distance: CGFloat, _ degrees: Double) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(x: center.x + distance * cos(radians),
                       y: center.y + distance * sin(radians))
    }

    private var kaabaMarker: some View {
        let ring = isAligned ? Color.green : Palette.accent
        return ZStack {
            // Rozet açık renk: Kâbe gövdesi koyu olduğu için koyu kadran üzerinde
            // doğrudan çizilince kayboluyor.
            Circle()
                .fill(Color(red: 0.96, green: 0.94, blue: 0.88))
                .frame(width: 38, height: 38)
            Circle()
                .stroke(ring, lineWidth: isAligned ? 2.5 : 1.5)
                .frame(width: 38, height: 38)
            KaabaGlyph()
                .frame(width: 21, height: 21)
        }
        // İşaret kadranla birlikte yatmasın; hep dik dursun.
        .rotationEffect(.degrees(-(qiblaDirection - heading)))
    }
}
