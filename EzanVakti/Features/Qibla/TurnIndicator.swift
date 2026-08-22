import SwiftUI

/// Kadranın ortasında duran dönüş talimatı.
///
/// Sapma açısını üstte küçük bir satır olarak yazmak yeterince belli olmuyordu;
/// asıl yapılacak iş bu olduğu için ekranın merkezine alındı ve yönü gösteren
/// kavisli bir okla desteklendi. Ok, dönülmesi gereken yöne doğru hafifçe
/// salınıyor — hareket "çevirmeye devam et"i sözcük kullanmadan anlatıyor.
struct TurnIndicator: View {
    /// Pozitif = sağa dön, negatif = sola.
    let deviation: Double
    let isAligned: Bool

    @State private var nudge = false

    private var clockwise: Bool { deviation > 0 }
    private var degrees: Int { abs(Int(deviation.rounded())) }

    var body: some View {
        if isAligned {
            VStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .scaledFont(34, weight: .semibold)
                    .foregroundStyle(Color(red: 0.35, green: 0.82, blue: 0.48))
                Text("Kıble yönünde")
                    .scaledFont(15, weight: .medium)
                    .foregroundStyle(.white.opacity(0.8))
            }
        } else {
            VStack(spacing: 12) {
                TurnArrow()
                    .stroke(Palette.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 96, height: 54)
                    // Sola dönüşte aynı çizimi aynalıyoruz; iki ayrı yol çizmek
                    // simetriyi elde bozma riski taşıyor.
                    .scaleEffect(x: clockwise ? 1 : -1)
                    .rotationEffect(.degrees(nudge ? (clockwise ? 7 : -7) : 0))
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                               value: nudge)

                VStack(spacing: 2) {
                    Text("\(degrees)°")
                        .scaledFont(30, weight: .semibold, design: .rounded)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text(clockwise ? "sağa dön" : "sola dön")
                        .scaledFont(15, weight: .medium)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .onAppear { nudge = true }
        }
    }
}

/// Saat yönünde dönüşü anlatan kavisli ok: üstten geçen yay + ucunda başlık.
struct TurnArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = min(rect.width / 2, rect.height) - 6

        // Yay: soldan üstten sağa (ekranda saat yönü).
        path.addArc(center: center, radius: radius,
                    startAngle: .degrees(180), endAngle: .degrees(342),
                    clockwise: false)

        // Ok başı, yayın bittiği noktada teğet yönünde.
        let tip = CGPoint(
            x: center.x + radius * cos(342 * .pi / 180),
            y: center.y + radius * sin(342 * .pi / 180)
        )
        let heading = (342 + 90) * Double.pi / 180
        let size: CGFloat = 11
        for spread in [2.5, -2.5] {
            let angle = heading + spread
            path.move(to: tip)
            path.addLine(to: CGPoint(x: tip.x + size * cos(angle),
                                     y: tip.y + size * sin(angle)))
        }
        return path
    }
}
