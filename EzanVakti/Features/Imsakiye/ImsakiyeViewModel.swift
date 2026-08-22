import Foundation
import Observation

struct ImsakiyeRow: Identifiable {
    let date: Date
    let day: Int
    let weekday: String
    let times: DailyPrayerTimes
    let isRamadan: Bool
    let isToday: Bool

    var id: Int { day }
}

@Observable
final class ImsakiyeViewModel {
    private(set) var coordinate: Coordinate = .istanbul
    private(set) var locationName = "İstanbul"
    var timeZone: TimeZone = .current

    /// Görüntülenen ayın ilk günü.
    private(set) var month: Date

    private var cache: [Date: [ImsakiyeRow]] = [:]

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    init(reference: Date = Date()) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        month = calendar.date(from: calendar.dateComponents([.year, .month], from: reference))
            ?? reference
    }

    func apply(_ state: LocationState) {
        guard case .resolved(let coordinate, let name) = state else { return }
        self.coordinate = coordinate
        self.locationName = name
        cache.removeAll()
    }

    // MARK: - Ay gezinme

    func step(_ months: Int) {
        guard let next = calendar.date(byAdding: .month, value: months, to: month) else { return }
        month = next
    }

    func goToCurrentMonth() {
        let now = Date()
        month = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
    }

    var isShowingCurrentMonth: Bool {
        calendar.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    var monthTitle: String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: month)
    }

    /// Ayın kapsadığı hicri ay(lar) — başlık altında gösteriliyor.
    var hijriSpan: String {
        var hijri = Calendar(identifier: .islamicUmmAlQura)
        hijri.timeZone = timeZone
        let monthName = DateFormatter()
        monthName.calendar = hijri
        monthName.timeZone = timeZone
        monthName.locale = Locale(identifier: "tr_TR")
        monthName.dateFormat = "LLLL"

        let yearName = DateFormatter()
        yearName.calendar = hijri
        yearName.timeZone = timeZone
        yearName.locale = Locale(identifier: "tr_TR")
        yearName.dateFormat = "yyyy"

        guard let range = calendar.range(of: .day, in: .month, for: month),
              let last = calendar.date(byAdding: .day, value: range.count - 1, to: month)
        else { return "" }

        let firstMonth = monthName.string(from: month)
        let lastMonth = monthName.string(from: last)
        let firstYear = yearName.string(from: month)
        let lastYear = yearName.string(from: last)

        if firstMonth == lastMonth { return "\(firstMonth) \(lastYear)" }
        // Yıl aynıysa iki kez yazmıyoruz: "Şaban – Ramazan 1448".
        if firstYear == lastYear { return "\(firstMonth) – \(lastMonth) \(lastYear)" }
        return "\(firstMonth) \(firstYear) – \(lastMonth) \(lastYear)"
    }

    // MARK: - Satırlar

    func rows() -> [ImsakiyeRow] {
        if let cached = cache[month] { return cached }

        let calculator = PrayerTimesCalculator(coordinate: coordinate, parameters: .diyanet)
        var hijri = Calendar(identifier: .islamicUmmAlQura)
        hijri.timeZone = timeZone

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.timeZone = timeZone
        weekdayFormatter.locale = Locale(identifier: "tr_TR")
        weekdayFormatter.dateFormat = "EEEEEE"

        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let today = calendar.startOfDay(for: Date())

        let result: [ImsakiyeRow] = range.compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 1, to: month),
                  let times = calculator.times(for: date, in: timeZone) else { return nil }
            return ImsakiyeRow(
                date: date,
                day: offset,
                weekday: weekdayFormatter.string(from: date),
                times: times,
                isRamadan: hijri.component(.month, from: date) == 9,
                isToday: calendar.isDate(date, inSameDayAs: today)
            )
        }

        // Ay değiştikçe eski aylar birikmesin; birkaç ay yeterli.
        if cache.count > 6 { cache.removeAll() }
        cache[month] = result
        return result
    }

    /// Ay Ramazan'a değiyorsa imsak ve akşam sütunları öne çıkarılıyor.
    var containsRamadan: Bool { rows().contains(where: \.isRamadan) }

    func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
