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
    /// Konum çözülene kadar İstanbul'la çalışıyoruz. Ekran bunu söylemek zorunda:
    /// vakitler her hâlükârda dolu göründüğü için sessiz kalmak, başka bir şehrin
    /// vakitlerini doğruymuş gibi sunmak demek.
    private(set) var isUsingFallbackLocation = true

    /// `.autoupdatingCurrent`: saat günlerce açık kalıyor, `.current` ise bir kez
    /// okunan donmuş bir kopya — dilim değişince vakitler sessizce kayıyordu.
    var timeZone: TimeZone = .autoupdatingCurrent {
        didSet { rebuildFormatter(); cache.removeAll() }
    }

    /// Yalnızca ezberleme; gerçek kaynak `coordinate` ve `timeZone`.
    /// `@ObservationIgnored` şart: `times(for:)` görünüm gövdesi çizilirken
    /// hem okuyor hem yazıyor, izlenen bir alan olsaydı bu "görünüm
    /// güncellenirken durum değiştirme" olurdu.
    @ObservationIgnored private var cache: [Date: DailyPrayerTimes] = [:]
    /// Biçimleyici saklanıyor: tek karede altı hücre ve kahraman alan yedi kez
    /// biçimleme istiyor, `DateFormatter` kurulumu bunun için fazla pahalı.
    private let timeFormatter = DateFormatter()

    init() { rebuildFormatter() }

    func apply(coordinate: Coordinate, name: String) {
        self.coordinate = coordinate
        self.locationName = name
        self.isUsingFallbackLocation = false
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

    /// Sıradaki vakte kalan sürenin sözcüklü hâli. Son 10 dakikada `nil` —
    /// orada saniye anlamlı ve sayaç sistemin kendi kendine ilerleyen metnine
    /// bırakılıyor. Biçimin gerekçesi `RemainingTime`'da.
    func remainingReadout(at now: Date) -> RemainingReadout? {
        guard let upcoming = upcoming(at: now) else { return nil }
        return RemainingTime.readout(to: upcoming.date, at: now, showsSeconds: false)
    }

    /// İçinde bulunulan vaktin anı — geri sayımın sabit alt ucu.
    ///
    /// Aralık "şu an"la kurulunca her yeniden çizimde yeni bir aralık oluyor ve
    /// sistemin kendi kendine ilerleyen sayacı baştan kuruluyordu; bu değer
    /// vakit girene kadar değişmediği için aralık dakikalarca aynı kalıyor.
    /// Gece yarısı ile imsak arasında bugünün listesinde önceki vakit yok;
    /// dünün yatsısına düşmezsek aralık gün başında çöküyor.
    /// Bugünün ve yarının vakit anları — zaman çizelgesine sınır olarak veriliyor.
    /// Vakitler belirlenimci olduğu için bunları önceden bilebiliyoruz.
    func upcomingBoundaries(after now: Date) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var result: [Date] = []
        for offset in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let times = times(for: day) else { continue }
            result.append(contentsOf: times.ordered.map(\.date))
        }
        return result.filter { $0 > now }.sorted()
    }

    func previousBoundary(at now: Date) -> Date? {
        if let day = times(for: now), let current = day.current(at: now) { return day[current] }

        // İmsaktan önceyiz: sınır dünün son vakti. İki tuzak var — sabit `[.yatsi]`
        // almak, yatsının imsaktan sonraya düştüğü enlemlerde geleceğe düşen bir alt
        // uç veriyor; `-24 * 3600` çıkarmak da yaz saati geçişindeki 23 saatlik günde
        // bir gün fazla geriye gidiyor. Takvimle gün çıkarıp dünün `current`ini
        // sormak ikisini de kapatıyor: tanımı gereği `now`dan küçük bir an dönüyor.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let back = calendar.date(byAdding: .day, value: -1, to: now),
              let yesterday = times(for: back),
              let current = yesterday.current(at: now)
        else { return nil }
        return yesterday[current]
    }

    func formatted(_ date: Date) -> String { timeFormatter.string(from: date) }

    /// `en_US_POSIX`: sabit "HH:mm" deseni yerelden bağımsız kalsın. Cihaz
    /// 12 saatlik biçime ayarlıysa desen sessizce AM/PM'e dönüyor.
    private func rebuildFormatter() {
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.timeZone = timeZone
        timeFormatter.dateFormat = "HH:mm"
    }
}
