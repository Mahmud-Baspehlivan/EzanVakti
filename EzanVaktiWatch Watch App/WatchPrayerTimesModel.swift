import Foundation
import Observation

/// Saat tarafı görünüm modeli.
///
/// Telefonla veri paylaşmıyor: vakitler hesaplanabilir olduğu için saat kendi
/// konumunu alıp kendi hesaplıyor. Böylece `WatchConnectivity` olmadan da
/// telefon yanında değilken çalışıyor.
@Observable
final class WatchPrayerTimesModel {
    private(set) var coordinate: Coordinate = .istanbul
    private(set) var locationName = "İstanbul"
    var timeZone: TimeZone = .current

    private var cache: [Date: DailyPrayerTimes] = [:]

    func apply(coordinate: Coordinate, name: String) {
        self.coordinate = coordinate
        self.locationName = name
        cache.removeAll()
    }

    func times(for date: Date) -> DailyPrayerTimes? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let key = calendar.startOfDay(for: date)
        if let cached = cache[key] { return cached }
        guard let computed = PrayerTimesCalculator(coordinate: coordinate, parameters: .diyanet)
            .times(for: date, in: timeZone) else { return nil }
        if cache.count > 3 { cache.removeAll() }
        cache[key] = computed
        return computed
    }

    func upcoming(at now: Date) -> (prayer: Prayer, date: Date)? {
        if let next = times(for: now)?.next(after: now) { return next }
        guard let tomorrow = times(for: now.addingTimeInterval(24 * 3600)) else { return nil }
        return (.imsak, tomorrow[.imsak])
    }

    func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
