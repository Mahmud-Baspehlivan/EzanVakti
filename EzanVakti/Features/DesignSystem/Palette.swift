import SwiftUI

/// Uygulamanın tek görsel kaynağı: arka plan tonları ve vurgu rengi.
/// Ekranlar bunu paylaşınca uygulama monte edilmiş değil tasarlanmış duruyor.
enum Palette {
    /// Kıble işaretindeki altınla aynı aile; uygulamadaki tek vurgu rengi.
    static let accent = Color(red: 0.91, green: 0.78, blue: 0.45)

    /// Tonlar bilerek koyu ve düşük doygunlukta: beyaz metnin üstünde durduğu
    /// zemin açıldıkça okunurluk düşüyor.

    static func background(for prayer: Prayer?) -> LinearGradient {
        let stops: [Color]
        switch prayer {
        case .imsak:
            stops = [Color(red: 0.06, green: 0.07, blue: 0.16), Color(red: 0.16, green: 0.14, blue: 0.28)]
        case .gunes:
            stops = [Color(red: 0.10, green: 0.12, blue: 0.24), Color(red: 0.30, green: 0.20, blue: 0.24)]
        case .ogle:
            stops = [Color(red: 0.06, green: 0.13, blue: 0.26), Color(red: 0.10, green: 0.22, blue: 0.34)]
        case .ikindi:
            stops = [Color(red: 0.08, green: 0.12, blue: 0.24), Color(red: 0.26, green: 0.19, blue: 0.22)]
        case .aksam:
            stops = [Color(red: 0.14, green: 0.08, blue: 0.18), Color(red: 0.32, green: 0.15, blue: 0.16)]
        case .yatsi, .none:
            stops = [Color(red: 0.04, green: 0.05, blue: 0.13), Color(red: 0.10, green: 0.10, blue: 0.21)]
        }
        return LinearGradient(colors: stops, startPoint: .top, endPoint: .bottom)
    }
}

/// Bölüm başlığı — uygulama genelinde tek biçim.
///
/// Büyük harfe çevirme Türkçe yerelle yapılıyor: varsayılan `uppercased()`
/// "İkindi"yi "İKINDI" yapıyor, doğrusu "İKİNDİ".
struct SectionLabel: View {
    let text: String
    var size: CGFloat = 12
    var tracking: CGFloat = 1.8

    private static let turkish = Locale(identifier: "tr_TR")

    var body: some View {
        Text(text.uppercased(with: Self.turkish))
            .scaledFont(size, weight: .semibold)
            .tracking(tracking)
            .foregroundStyle(Palette.accent)
    }
}
