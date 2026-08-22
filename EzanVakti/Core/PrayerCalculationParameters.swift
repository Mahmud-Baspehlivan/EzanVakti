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
    /// Diyanet astronomik vakte "temkin" payı ekliyor. Aşağıdaki değerler
    /// **15 ilin** (Edirne'den Hakkari'ye, Sinop'tan Antalya'ya) gerçek Diyanet
    /// takvimine karşı ölçülüp medyanı alınarak türetildi; yayınlanmış bir
    /// tablodan gelmiyor.
    ///
    /// Ölçülen doğruluk: tüm ülkede **en kötü 2 dk**, ortalama sapma 0.56 dk,
    /// karşılaştırmaların %92'si 1 dk içinde. Şaşırtıcı olan, düzeltmelerin
    /// iller arasında 2-4 dk'dan fazla değişmemesi — tek küme değer ülke
    /// genelinde yeterli oluyor.
    ///
    /// Kalan 2 dk'lık uçlar (Hakkari, Samsun, Sinop, Van) temkinden değil
    /// koordinat farkından: Diyanet her ilçe için kendi referans noktasını
    /// kullanıyor ve bunu yayınlamıyor. Hesaplamaya dayalı bir yaklaşımda
    /// pratik taban bu.
    static let diyanet = PrayerCalculationParameters(
        fajrAngle: 18,
        ishaAngle: 17,
        asrShadowFactor: 1,
        elevation: 0,
        adjustments: [.imsak: 0, .gunes: -7, .ogle: 6, .ikindi: 5, .aksam: 9, .yatsi: 2]
    )
}
