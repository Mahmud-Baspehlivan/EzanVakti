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
    /// Bir önceki vaktin anı — ilerleme oranı için.
    let previousTime: Date
    let locationName: String

    func progress(at now: Date) -> Double {
        let total = prayerTime.timeIntervalSince(previousTime)
        guard total > 0 else { return 0 }
        return min(1, max(0, now.timeIntervalSince(previousTime) / total))
    }

    /// Sıradaki `count` vakit için içerik üretir.
    ///
    /// Birden fazlası gerekiyor çünkü iOS 26'da etkinlikler ileri tarihe
    /// zamanlanabiliyor; uygulama açılmasa bile sonraki vakitler görünüyor.
    static func upcoming(count: Int, coordinate: Coordinate, locationName: String,
                         timeZone: TimeZone, now: Date = Date()) -> [PrayerActivityContent] {
        let calculator = PrayerTimesCalculator(coordinate: coordinate, parameters: .diyanet)
        var slots: [(prayer: Prayer, date: Date)] = []
        for dayOffset in 0...2 {
            let day = now.addingTimeInterval(Double(dayOffset) * 24 * 3600)
            guard let times = calculator.times(for: day, in: timeZone) else { continue }
            slots.append(contentsOf: times.ordered)
        }
        slots.sort { $0.date < $1.date }

        var result: [PrayerActivityContent] = []
        for (index, slot) in slots.enumerated() where slot.date > now {
            // Önceki vakit ilerleme oranının başlangıcı; ilk kayıtta yoksa
            // aralığı bir saatlik varsayıyoruz, çubuk yine de dolar.
            let previous = index > 0 ? slots[index - 1].date
                                     : slot.date.addingTimeInterval(-3600)
            result.append(PrayerActivityContent(prayer: slot.prayer, prayerTime: slot.date,
                                                previousTime: previous,
                                                locationName: locationName))
            if result.count == count { break }
        }
        return result
    }

    /// Uygulamanın o anki durumundan üretir. Sıradaki vakit yoksa nil.
    static func make(coordinate: Coordinate, locationName: String,
                     timeZone: TimeZone, now: Date = Date()) -> PrayerActivityContent? {
        let calculator = PrayerTimesCalculator(coordinate: coordinate, parameters: .diyanet)
        guard let today = calculator.times(for: now, in: timeZone) else { return nil }

        let ordered = today.ordered
        if let next = ordered.first(where: { $0.date > now }) {
            let previous = ordered.last { $0.date <= now }?.date
                ?? calculator.times(for: now.addingTimeInterval(-24 * 3600), in: timeZone)?[.yatsi]
                ?? now
            return PrayerActivityContent(prayer: next.prayer, prayerTime: next.date,
                                         previousTime: previous, locationName: locationName)
        }

        // Yatsıdan sonra: yarının imsakı.
        guard let tomorrow = calculator.times(for: now.addingTimeInterval(24 * 3600), in: timeZone)
        else { return nil }
        return PrayerActivityContent(prayer: .imsak, prayerTime: tomorrow[.imsak],
                                     previousTime: today[.yatsi], locationName: locationName)
    }
}
