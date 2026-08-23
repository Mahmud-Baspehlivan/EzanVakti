import Foundation
import WidgetKit

struct PrayerSlot: Identifiable {
    let prayer: Prayer
    let date: Date
    var id: String { prayer.rawValue }
}

/// Widget'ın bir andaki içeriği.
///
/// `TimelineEntry` uyumu burada: hem iOS widget'ı hem saat komplikasyonu bu
/// dosyayı paylaşıyor, uyum tek yerde durmalı. (Önce iOS widget dosyasındaydı
/// ve saat hedefi derlenmiyordu.)
struct PrayerEntry: TimelineEntry {
    let date: Date
    let locationName: String
    let slots: [PrayerSlot]
    let upcoming: PrayerSlot?
    /// Bir önceki vaktin anı — ilerleme halkası için. Gün başında nil olabilir.
    let previous: Date?
    /// Konum paylaşımı kurulmamışsa varsayılan şehir gösteriliyor demektir.
    let isUsingFallbackLocation: Bool

    var progress: Double {
        guard let upcoming, let previous else { return 0 }
        let total = upcoming.date.timeIntervalSince(previous)
        guard total > 0 else { return 0 }
        return min(1, max(0, date.timeIntervalSince(previous) / total))
    }

    static func make(at date: Date, coordinate: Coordinate, name: String,
                     timeZone: TimeZone, isFallback: Bool) -> PrayerEntry {
        let calculator = PrayerTimesCalculator(coordinate: coordinate, parameters: .diyanet)
        guard let today = calculator.times(for: date, in: timeZone) else {
            return PrayerEntry(date: date, locationName: name, slots: [],
                               upcoming: nil, previous: nil, isUsingFallbackLocation: isFallback)
        }

        let slots = today.ordered.map { PrayerSlot(prayer: $0.prayer, date: $0.date) }

        var upcoming = slots.first { $0.date > date }
        if upcoming == nil,
           let tomorrow = calculator.times(for: date.addingTimeInterval(24 * 3600), in: timeZone) {
            upcoming = PrayerSlot(prayer: .imsak, date: tomorrow[.imsak])
        }

        // Gece yarısı ile imsak arasında bugünün listesinde önceki vakit yok;
        // dünün yatsısına düşmezsek ilerleme halkası gece yarısında sıfırlanıyor.
        var previous = slots.last { $0.date <= date }?.date
        if previous == nil,
           let yesterday = calculator.times(for: date.addingTimeInterval(-24 * 3600), in: timeZone) {
            previous = yesterday[.yatsi]
        }

        return PrayerEntry(date: date, locationName: name, slots: slots,
                           upcoming: upcoming, previous: previous,
                           isUsingFallbackLocation: isFallback)
    }
}
