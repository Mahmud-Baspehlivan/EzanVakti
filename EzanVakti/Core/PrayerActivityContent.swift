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
