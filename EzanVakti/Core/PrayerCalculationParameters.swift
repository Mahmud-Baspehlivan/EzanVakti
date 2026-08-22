import Foundation

struct PrayerCalculationParameters {
    /// Sabah namazının başladığı güneş irtifası (ufkun altında, derece).
    var fajrAngle: Double
    /// Yatsının başladığı güneş irtifası.
    var ishaAngle: Double
    /// İkindi gölge çarpanı: 1 = Şâfiî, 2 = Hanefî.
    var asrShadowFactor: Double
    /// Rakım (metre). Doğuş/batışı öne/arkaya kaydırır.
    var elevation: Double
    /// Vakit başına dakika düzeltmesi.
    var adjustments: [Prayer: Int]

    /// Çıplak astronomik değerler — düzeltme yok.
    /// Gerçek doğuş/batış, Diyanet'in kendi astronomik alanlarına 1-2 dk içinde oturuyor.
    static let astronomical = PrayerCalculationParameters(
        fajrAngle: 18,
        ishaAngle: 17,
        asrShadowFactor: 1,
        elevation: 0,
        adjustments: [:]
    )

    /// Diyanet'in yayınladığı takvime oturtulmuş sürüm.
    ///
    /// Diyanet astronomik vakte "temkin" payı ekler; aşağıdaki değerler İstanbul /
    /// Ağustos 2026 takviminin 17 gününe karşı ölçülerek türetildi, yayınlanmış bir
    /// tablodan alınmadı. Temkin şehre göre değiştiği için başka illerde birkaç
    /// dakika sapabilir — kalibrasyonu genişletmeden ülke geneline genellemeyin.
    static let diyanet = PrayerCalculationParameters(
        fajrAngle: 18,
        ishaAngle: 17,
        asrShadowFactor: 1,
        elevation: 0,
        adjustments: [.imsak: 0, .gunes: -6, .ogle: 6, .ikindi: 5, .aksam: 9, .yatsi: 2]
    )
}
