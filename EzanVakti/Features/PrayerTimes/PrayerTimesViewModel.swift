import Foundation
import Observation

@Observable
final class PrayerTimesViewModel {
    private(set) var coordinate: Coordinate = .istanbul
    private(set) var locationName = "İstanbul"
    /// Konum çözülemediğinde İstanbul'la çalışıyoruz; ekran bunu ayrıca bildiriyor.
    private(set) var isUsingFallbackLocation = true

    /// `autoupdatingCurrent`: uçakla dilim değiştirmek bu uygulamanın ana
    /// senaryosu (seyahat, umre/hac). Anlık görüntü alınsaydı vakitler kalkış
    /// şehrinde donup kalırdı.
    var timeZone: TimeZone = .autoupdatingCurrent {
        didSet { rebuildFormatters(); cache.removeAll() }
    }

    /// Yalnızca ezberleme; gerçek kaynak `coordinate` ve `timeZone`.
    /// `@ObservationIgnored` şart: `times(for:)` görünüm gövdesi çizilirken
    /// hem okuyor hem yazıyor, izlenen bir alan olsaydı bu "görünüm
    /// güncellenirken durum değiştirme" olurdu.
    ///
    /// Saat dilimi değişimi için ayrıca bildirim dinlemeye gerek yok: anahtar
    /// `startOfDay` ve `timeZone` `.autoupdatingCurrent`. Ölçüldü — saklanan
    /// `Calendar` sistem dilimini izliyor, dolayısıyla dilim değişince anahtar
    /// da değişiyor ve önbellek kendiliğinden ıskalıyor.
    @ObservationIgnored private var cache: [Date: DailyPrayerTimes] = [:]
    private let timeFormatter = DateFormatter()
    private let gregorianFormatter = DateFormatter()
    private let hijriFormatter = DateFormatter()

    init() { rebuildFormatters() }

    func apply(_ state: LocationState) {
        switch state {
        case .resolved(let coordinate, let name):
            self.coordinate = coordinate
            self.locationName = name
            self.isUsingFallbackLocation = false
            cache.removeAll()
        case .denied, .failed:
            guard !isUsingFallbackLocation else { return }
            coordinate = .istanbul
            locationName = "İstanbul"
            isUsingFallbackLocation = true
            cache.removeAll()
        case .idle, .requesting:
            break
        }
    }

    // MARK: - Vakitler

    /// Bildirim planlayıcı da aynı çekirdeği kullanıyor; ekranla plan arasında
    /// yöntem farkı oluşmasın diye tek yerden veriliyor.
    var calculator: PrayerTimesCalculator {
        PrayerTimesCalculator(coordinate: coordinate, parameters: .diyanet)
    }

    /// Ekran saniyede bir yenilendiği için gün bazında önbelleğe alıyoruz.
    func times(for date: Date) -> DailyPrayerTimes? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let key = calendar.startOfDay(for: date)

        if let cached = cache[key] { return cached }
        guard let computed = calculator.times(for: date, in: timeZone) else { return nil }

        if cache.count > 4 { cache.removeAll() }
        cache[key] = computed
        return computed
    }

    /// Sıradaki vakit. Yatsı geçtiyse yarının imsakına taşıyor.
    func upcoming(at now: Date) -> (prayer: Prayer, date: Date)? {
        if let next = times(for: now)?.next(after: now) { return next }
        guard let tomorrow = times(for: now.addingTimeInterval(24 * 3600)) else { return nil }
        return (.imsak, tomorrow[.imsak])
    }

    /// Kalan süre. Uzakken sakin ("1 sa 46 dk"), son 10 dakikada saniyeye
    /// inip canlanıyor — ekran hem huzurlu duruyor hem yaklaşınca canlı hissettiriyor.
    func remaining(at now: Date) -> String {
        guard let upcoming = upcoming(at: now) else { return "—" }
        let seconds = max(0, Int(upcoming.date.timeIntervalSince(now)))

        if seconds < 600 {
            return String(format: "%d:%02d", seconds / 60, seconds % 60)
        }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours) sa \(minutes) dk" : "\(minutes) dk"
    }

    /// Geri sayımın yanındaki sözcük. "1 sa 46 dk sonra" Türkçede tuhaf duruyor,
    /// her durumda "kaldı".
    func remainingCaption(at now: Date) -> String {
        upcoming(at: now) == nil ? "" : "kaldı"
    }

    // MARK: - Biçimleme

    func formatted(_ date: Date) -> String { timeFormatter.string(from: date) }
    func gregorianDate(for date: Date) -> String { gregorianFormatter.string(from: date) }
    func hijriDate(for date: Date) -> String { hijriFormatter.string(from: date) }

    private func rebuildFormatters() {
        let turkish = Locale(identifier: "tr_TR")

        timeFormatter.timeZone = timeZone
        // Sabit biçimde locale zorunlu: kullanıcının "24 Saat" ayarı kapalıyken
        // sistem "HH:mm"i yeniden yorumlayıp 12 saatlik biçime çevirebiliyor.
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "HH:mm"

        gregorianFormatter.timeZone = timeZone
        gregorianFormatter.locale = turkish
        gregorianFormatter.dateFormat = "d MMMM EEEE"

        // Diyanet'in hicri tarihi Ümmü'l-Kura'dan bir gün sapabilir; ay başlarında
        // birebir tutmayabilir, v1'de sistem takvimiyle yetiniyoruz.
        var hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
        hijriCalendar.timeZone = timeZone
        hijriFormatter.calendar = hijriCalendar
        hijriFormatter.timeZone = timeZone
        hijriFormatter.locale = turkish
        hijriFormatter.dateFormat = "d MMMM yyyy"
    }
}
