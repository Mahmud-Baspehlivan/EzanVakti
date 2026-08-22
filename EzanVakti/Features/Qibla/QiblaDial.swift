import SwiftUI

/// Pusula kadranı. Kendi başına render edilebilsin diye ayrı tutuluyor —
/// böylece konum/pusula servisleri olmadan da görsel olarak denenebiliyor.
/// Kadranda derece yazısı olup olmayacağı.
enum DegreeLabelStyle {
    case none
    /// 30° aralıklarla; ana yönler harf olarak kalıyor.
    case every30
    /// Yalnızca köşegenlerde (45°); daha az kalabalık.
    case every45
}

struct QiblaDial: View {
    let qiblaDirection: Double
    let heading: Double
    let isAligned: Bool
    var degreeLabels: DegreeLabelStyle = .none

    private let radius: CGFloat = 148
    private var markerRadius: CGFloat { radius - 18 }

    var body: some View {
        ZStack {
            Circle().fill(.black.opacity(0.18))
            Circle().stroke(.white.opacity(0.14), lineWidth: 1)

            ForEach(0..<72, id: \.self) { index in
                let isCardinal = index % 18 == 0
                let isMajor = index % 6 == 0
                Rectangle()
                    .fill(.white.opacity(isCardinal ? 0.85 : (isMajor ? 0.5 : 0.28)))
                    .frame(width: isCardinal ? 2 : 1, height: isCardinal ? 14 : (isMajor ? 10 : 6))
                    .offset(y: -(radius - 8))
                    .rotationEffect(.degrees(Double(index) * 5))
            }

            ForEach(Array(["K", "D", "G", "B"].enumerated()), id: \.offset) { item in
                let angle = Double(item.offset) * 90
                Text(item.element)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(item.offset == 0 ? 0.9 : 0.5))
                    // Kadran dönerken harf dik kalsın; aksi halde güney "G" baş aşağı okunuyor.
                    .rotationEffect(.degrees(-(angle - heading)))
                    .offset(y: -(radius - 32))
                    .rotationEffect(.degrees(angle))
            }

            degreeMarks

            kaabaMarker
                .offset(y: -markerRadius)
                .rotationEffect(.degrees(qiblaDirection))
        }
        .rotationEffect(.degrees(-heading))
        .frame(width: radius * 2, height: radius * 2)
    }

    @ViewBuilder
    private var degreeMarks: some View {
        let step: Int? = {
            switch degreeLabels {
            case .none: return nil
            case .every30: return 30
            case .every45: return 45
            }
        }()

        if let step {
            ForEach(Array(stride(from: 0, to: 360, by: step)), id: \.self) { degree in
                // Ana yönlerde harf zaten var; sayı koyup üst üste bindirmiyoruz.
                if degree % 90 != 0 {
                    Text("\(degree)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.38))
                        .rotationEffect(.degrees(-(Double(degree) - heading)))
                        .offset(y: -(radius - 32))
                        .rotationEffect(.degrees(Double(degree)))
                }
            }
        }
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
