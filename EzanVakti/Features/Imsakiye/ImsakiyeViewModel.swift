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
    /// `autoupdatingCurrent`: uçakla dilim değiştirmek bu uygulamanın ana
    /// senaryosu (seyahat, umre/hac). Anlık görüntü alınsaydı imsakiye kalkış
    /// şehrinde donup kalırdı.
    var timeZone: TimeZone = .autoupdatingCurrent {
        didSet { rebuildFormatters(); cache.removeAll() }
    }

    /// Görüntülenen ayın ilk günü.
    private(set) var month: Date

    /// Yalnızca ezberleme; gerçek kaynak `coordinate` ve `timeZone`.
    /// `@ObservationIgnored` şart: `times(for:)` görünüm gövdesi çizilirken
    /// hem okuyor hem yazıyor, izlenen bir alan olsaydı bu "görünüm
    /// güncellenirken durum değiştirme" olurdu.
    @ObservationIgnored private var cache: [Date: [ImsakiyeRow]] = [:]

    /// Takvim ve biçimleyiciler yalnız saat diliminden türüyor. Tablo bir ayda
    /// 180 hücre çiziyor; kurulumları hücre başına yapmak `DateFormatter`ın en
    /// pahalı işini boş yere tekrarlamak olurdu.
    @ObservationIgnored private var calendar = Calendar(identifier: .gregorian)
    @ObservationIgnored private var hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
    private let timeFormatter = DateFormatter()
    private let monthTitleFormatter = DateFormatter()
    private let weekdayFormatter = DateFormatter()
    private let hijriMonthFormatter = DateFormatter()
    private let hijriYearFormatter = DateFormatter()

    init(reference: Date = Date()) {
        // Saklanan takvim henüz kurulmadığı için ilk ayı yerel bir kopyayla buluyoruz.
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = .autoupdatingCurrent
        month = gregorian.date(from: gregorian.dateComponents([.year, .month], from: reference))
            ?? reference
        rebuildFormatters()
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

    var monthTitle: String { monthTitleFormatter.string(from: month) }

    /// Ayın kapsadığı hicri ay(lar) — başlık altında gösteriliyor.
    var hijriSpan: String {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let last = calendar.date(byAdding: .day, value: range.count - 1, to: month)
        else { return "" }

        let firstMonth = hijriMonthFormatter.string(from: month)
        let lastMonth = hijriMonthFormatter.string(from: last)
        let firstYear = hijriYearFormatter.string(from: month)
        let lastYear = hijriYearFormatter.string(from: last)

        if firstMonth == lastMonth { return "\(firstMonth) \(lastYear)" }
        // Yıl aynıysa iki kez yazmıyoruz: "Şaban – Ramazan 1448".
        if firstYear == lastYear { return "\(firstMonth) – \(lastMonth) \(lastYear)" }
        return "\(firstMonth) \(firstYear) – \(lastMonth) \(lastYear)"
    }

    // MARK: - Satırlar

    func rows() -> [ImsakiyeRow] {
        // Observation bağımlılığı okuma anında kuruluyor. Önbellek `@ObservationIgnored`
        // olduğu için, dolu olduğunda erken dönersek bu görünüm hiçbir izlenen alana
        // dokunmamış olur; konum değişip önbellek temizlendiğinde başlık yenilenir ama
        // tablo eski şehrin vakitlerinde kalırdı. `month` zaten anahtar olarak okunuyor.
        let coordinate = self.coordinate
        let timeZone = self.timeZone
        if let cached = cache[month] { return cached }

        let calculator = PrayerTimesCalculator(coordinate: coordinate, parameters: .diyanet)

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
                isRamadan: hijriCalendar.component(.month, from: date) == 9,
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

    // MARK: - Biçimleme

    func formatted(_ date: Date) -> String { timeFormatter.string(from: date) }

    private func rebuildFormatters() {
        let turkish = Locale(identifier: "tr_TR")

        calendar.timeZone = timeZone
        hijriCalendar.timeZone = timeZone

        timeFormatter.timeZone = timeZone
        // Sabit biçimde locale zorunlu: kullanıcının "24 Saat" ayarı kapalıyken
        // sistem "HH:mm"i yeniden yorumlayıp 12 saatlik biçime çevirebiliyor.
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "HH:mm"

        // Ay ve gün adları kullanıcıya gösteriliyor; onlar Türkçe kalıyor.
        monthTitleFormatter.timeZone = timeZone
        monthTitleFormatter.locale = turkish
        monthTitleFormatter.dateFormat = "LLLL yyyy"

        weekdayFormatter.timeZone = timeZone
        weekdayFormatter.locale = turkish
        weekdayFormatter.dateFormat = "EEEEEE"

        hijriMonthFormatter.calendar = hijriCalendar
        hijriMonthFormatter.timeZone = timeZone
        hijriMonthFormatter.locale = turkish
        hijriMonthFormatter.dateFormat = "LLLL"

        hijriYearFormatter.calendar = hijriCalendar
        hijriYearFormatter.timeZone = timeZone
        hijriYearFormatter.locale = turkish
        hijriYearFormatter.dateFormat = "yyyy"
    }
}
