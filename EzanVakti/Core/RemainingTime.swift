import Foundation

/// Geri sayımın bir parçası: büyük sayı + küçük birim.
///
/// Düz "6 sa 21 dk" tek puntoda dar ekrana sığmıyor; birimi küçültmek genişliği
/// yarıya indiriyor. Aynı zamanda saatteki süre gösteriminin yerleşik dili.
struct RemainingPart: Equatable, Identifiable {
    let value: String
    let unit: String
    var id: String { unit }
}

struct RemainingReadout: Equatable {
    let parts: [RemainingPart]
    /// Kısaltmasız hâl. "sa"/"dk" ekrana sığmak için var; VoiceOver onları harf
    /// harf ya da yanlış okuyor, sesli okunan bu alan.
    let spoken: String
}

/// Kalan sürenin sözcüklü biçimi.
///
/// Neden ham `s:dd:ss` değil: sistemin sayaç biçimi saat hanesi sıfırken onu
/// düşürüyor, yani `6:21` ile `6:21:34` aynı ekranda birbirinin yerine geçiyor
/// ve vakte altı dakika kalan bir sayaç "altı saat var" diye okunabiliyor.
/// Birim yazılınca o karışıklık kalmıyor.
///
/// Çekirdekte, çünkü telefon ve saat aynı biçimi göstermek zorunda; iki yerde
/// ayrı yazılsaydı bir gün ayrışırlardı.
enum RemainingTime {
    /// Saniyeli gösterime geçiş eşiği. Üstünde saniye gürültü, altında anlamlı.
    static let secondsThreshold = 600

    /// - Parameters:
    ///   - showsSeconds: Eşiğin altında saniyeli hâl döner. `false` verilirse
    ///     `nil` dönüyor ve çağıran sistemin kendi kendine ilerleyen sayacına
    ///     düşüyor — saat böyle yapıyor, orada saniyelik yeniden çizim doğrudan
    ///     pil demek. Telefon saniyede bir zaten yenileniyor, orada `true`.
    static func readout(to target: Date, at now: Date, showsSeconds: Bool) -> RemainingReadout? {
        let total = max(0, Int(target.timeIntervalSince(now)))

        guard total >= secondsThreshold else {
            guard showsSeconds else { return nil }
            // Bir dakikanın altında "0 dk 12 sn" yazmak yerine tek birim.
            guard total >= 60 else { return make([(total, "sn", "saniye")]) }
            return make([(total / 60, "dk", "dakika"), (total % 60, "sn", "saniye")])
        }

        let hours = total / 3600
        guard hours > 0 else { return make([(total / 60, "dk", "dakika")]) }
        return make([(hours, "sa", "saat"), ((total % 3600) / 60, "dk", "dakika")])
    }

    private static func make(_ pieces: [(Int, String, String)]) -> RemainingReadout {
        RemainingReadout(
            parts: pieces.map { RemainingPart(value: "\($0.0)", unit: $0.1) },
            spoken: pieces.map { "\($0.0) \($0.2)" }.joined(separator: " ")
        )
    }
}
