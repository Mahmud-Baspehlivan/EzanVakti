import Foundation

/// Live Activity'nin gösterdiği veri.
///
/// ActivityKit'ten bilerek ayrı: bu tip saf Foundation kaldığı için görünümler
/// `Tools/render` ile Xcode olmadan basılıp denetlenebiliyor. ActivityKit
/// yalnızca iOS'ta var ve macOS tip denetimini kırıyor.
struct PrayerActivityContent: Codable, Hashable {
    let prayer: Prayer
    /// Sıradaki vaktin girdiği an.
    let prayerTime: Date
    /// Geri sayımın ve ilerleme çubuğunun başladığı an — yani etkinliğin
    /// ekranda göründüğü an. Önceki vaktin anı *değil*, bkz. `upcoming`.
    let windowStart: Date
    let locationName: String

    /// Alan `previousTime`'dan `windowStart`'a döndü, kodlama anahtarı eski
    /// adında kaldı: uygulama güncellenirken kilit ekranında duran bir etkinlik
    /// ActivityKit'in sakladığı eski yükle geri geliyor. Anahtar değişirse o
    /// yük çözülemiyor ve etkinlik `Activity.activities` listesine hiç düşmüyor
    /// — yani `endAll` onu bir daha kaldıramıyor, kilit ekranında asılı kalıyor.
    private enum CodingKeys: String, CodingKey {
        case prayer, prayerTime, locationName
        case windowStart = "previousTime"
    }

    func progress(at now: Date) -> Double {
        let total = prayerTime.timeIntervalSince(windowStart)
        guard total > 0 else { return 0 }
        return min(1, max(0, now.timeIntervalSince(windowStart) / total))
    }

    /// Sıradaki `count` vakit için içerik üretir.
    ///
    /// Birden fazlası gerekiyor çünkü iOS 26'da etkinlikler ileri tarihe
    /// zamanlanabiliyor; uygulama açılmasa bile sonraki vakitler görünüyor.
    ///
    /// `leadMinutes` yalnızca etkinliğin ne zaman göründüğünü değil geri
    /// sayımın aralığını da belirliyor; ikisi aynı pencere olmak zorunda, yoksa
    /// çubuk açıldığı anda yarı dolu başlıyor.
    static func upcoming(count: Int, leadMinutes: Int, coordinate: Coordinate,
                         locationName: String, timeZone: TimeZone,
                         now: Date = Date()) -> [PrayerActivityContent] {
        let calculator = PrayerTimesCalculator(coordinate: coordinate, parameters: .diyanet)
        var slots: [(prayer: Prayer, date: Date)] = []
        for dayOffset in 0...2 {
            let day = now.addingTimeInterval(Double(dayOffset) * 24 * 3600)
            guard let times = calculator.times(for: day, in: timeZone) else { continue }
            slots.append(contentsOf: times.ordered)
        }
        slots.sort { $0.date < $1.date }

        let lead = Double(leadMinutes) * 60
        var result: [PrayerActivityContent] = []
        for (index, slot) in slots.enumerated() where slot.date > now {
            // Önceki vakit ilerleme oranının başlangıcı; ilk kayıtta yoksa
            // aralığı bir saatlik varsayıyoruz, çubuk yine de dolar.
            let previous = index > 0 ? slots[index - 1].date
                                     : slot.date.addingTimeInterval(-3600)
            // Pencere önceki vakitte başlıyor ama lead'den uzun olmuyor. İki
            // sınır, iki ayrı sebep:
            //
            // - **lead sınırı:** Yatsı–İmsak kışın 11.5 saate çıkıyor. O aralığa
            //   yayılan bir çubuk gözle kımıldamıyor, sayaç da "11:29:58" gibi
            //   Dinamik Ada'ya sığmayan bir metin oluyor.
            // - **önceki vakit sınırı:** lead en kısa geçişten (Akşam–Yatsı
            //   79 dk) uzun seçilirse iki vaktin penceresi üst üste biniyor ve
            //   iki etkinlik aynı anda açık kalıyor. Ada o durumda minimal moda
            //   düşüyor; orada yalnız ikon var, geri sayım yok. Yani tam "ezana
            //   az kaldı" derken sayaç ekrandan kayboluyordu.
            let windowStart = max(previous, slot.date.addingTimeInterval(-lead))
            result.append(PrayerActivityContent(prayer: slot.prayer, prayerTime: slot.date,
                                                windowStart: windowStart,
                                                locationName: locationName))
            if result.count == count { break }
        }
        return result
    }
}
