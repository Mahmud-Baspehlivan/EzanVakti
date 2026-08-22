import SwiftUI

/// Kâbe işareti — vektör olarak çiziliyor: her boyutta keskin, telif sorunu yok.
///
/// Küçük boyda ayrıntı hayatta kalmadığı için sadeleştirildi: gövde, kuşak (hizam),
/// üst kenar şeridi ve kapı. Kapı gerçekteki gibi sağa kaymış ve yerden yüksek.
///
/// Gövde koyu olduğu için **açık zemin üzerinde** kullanılmalı; koyu zeminde
/// gövde kaybolup yalnızca altın şeritler görünüyor.
struct KaabaGlyph: View {
    var stone: Color = Color(red: 0.09, green: 0.09, blue: 0.11)
    var trim: Color = Color(red: 0.80, green: 0.62, blue: 0.22)

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: w * 0.05)
                    .fill(stone)
                    .frame(width: w * 0.88, height: h * 0.80)
                    .offset(x: w * 0.06, y: h * 0.16)

                // Üst kenar şeridi — ince, gövdeden hafif taşkın.
                RoundedRectangle(cornerRadius: w * 0.03)
                    .fill(trim)
                    .frame(width: w, height: h * 0.09)
                    .offset(x: 0, y: h * 0.08)

                // Kuşak (hizam)
                Rectangle()
                    .fill(trim)
                    .frame(width: w * 0.88, height: h * 0.12)
                    .offset(x: w * 0.06, y: h * 0.36)

                // Kapı: sağa kaymış, yere değmiyor.
                RoundedRectangle(cornerRadius: w * 0.02)
                    .fill(trim)
                    .frame(width: w * 0.17, height: h * 0.26)
                    .offset(x: w * 0.58, y: h * 0.62)
            }
        }
    }
}
