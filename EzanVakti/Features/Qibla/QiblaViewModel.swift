import Foundation
import Observation

@Observable
final class QiblaViewModel {
    private(set) var coordinate: Coordinate = .istanbul
    /// `autoupdatingCurrent`: uçakla dilim değiştirmek bu uygulamanın ana
    /// senaryosu (seyahat, umre/hac). Anlık görüntü alınsaydı kıble saati kalkış
    /// şehrinde donup kalırdı.
    var timeZone: TimeZone = .autoupdatingCurrent {
        didSet { rebuildFormatters(); cachedTimes = nil }
    }

    /// Pusula okumasının kıbleye oturduğu kabul edilen tolerans.
    static let alignmentTolerance: Double = 5

    @ObservationIgnored private var calendar = Calendar(identifier: .gregorian)
    private let timeFormatter = DateFormatter()

    /// Kıble saati günde bir kez değişir ama ekran pusula okumasına bağlı olduğu
    /// için saniyede onlarca kez yeniden çiziliyor. `@ObservationIgnored`: bu alan
    /// gövde çizilirken yazılıyor; izlenseydi her yazma yeni bir çizim doğururdu.
    @ObservationIgnored private var cachedTimes: (key: String, value: [Date])?

    init() { rebuildFormatters() }

    var direction: Double { Qibla.direction(from: coordinate) }

    func apply(_ state: LocationState) {
        if case .resolved(let coordinate, _) = state {
            self.coordinate = coordinate
        }
    }

    /// Cihazın baktığı yön ile kıble arasındaki işaretli sapma, ±180 aralığında.
    func deviation(from heading: Double) -> Double {
        var diff = direction - heading
        if diff > 180 { diff -= 360 } else if diff < -180 { diff += 360 }
        return diff
    }

    func isAligned(heading: Double) -> Bool {
        abs(deviation(from: heading)) <= Self.alignmentTolerance
    }

    /// Güneşin kıble yönüne geldiği an(lar). Bazı enlem ve tarihlerde hiç olmuyor,
    /// bazılarında günde iki kez oluyor.
    func qiblaTimes(on day: Date) -> [Date] {
        // Hesap günü dakika dakika tarıyor; anahtar gün + koordinat olunca hem
        // gece yarısında hem konum değişince kendiliğinden geçersizleşiyor.
        let key = "\(calendar.startOfDay(for: day).timeIntervalSinceReferenceDate)"
            + "|\(coordinate.latitude),\(coordinate.longitude)"
        if let cached = cachedTimes, cached.key == key { return cached.value }

        let times = Qibla.qiblaTimes(on: day, coordinate: coordinate, timeZone: timeZone)
        cachedTimes = (key, times)
        return times
    }

    /// Diyanet kıble saatini dakikaya yukarı yuvarlıyor; ölçtüğümüz 17 günün
    /// 14'ünde bu kural birebir tutuyor, kalanında sapma 1 dakika.
    func formattedMinute(_ date: Date) -> String {
        let seconds = calendar.component(.second, from: date)
        let rounded = seconds > 0 ? date.addingTimeInterval(Double(60 - seconds)) : date
        return timeFormatter.string(from: rounded)
    }

    var distanceText: String {
        let km = Qibla.distanceToKaaba(from: coordinate)
        return (Self.distanceFormatter.string(from: NSNumber(value: km)) ?? "\(Int(km))") + " km"
    }

    /// Saat diliminden bağımsız, yereli sabit: örneği tip düzeyinde bir kez kuruyoruz.
    private static let distanceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private func rebuildFormatters() {
        calendar.timeZone = timeZone

        timeFormatter.timeZone = timeZone
        // Sabit biçimde locale zorunlu: kullanıcının "24 Saat" ayarı kapalıyken
        // sistem "HH:mm"i yeniden yorumlayıp 12 saatlik biçime çevirebiliyor.
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "HH:mm"
    }

    /// Kadran üzerindeki kısa etiketler.
    func compassLabel(for degrees: Double) -> String {
        let names = ["K", "KKD", "KD", "DKD", "D", "DGD", "GD", "GGD",
                     "G", "GGB", "GB", "BGB", "B", "BKB", "KB", "KKB"]
        return names[sector(for: degrees) % names.count]
    }

    /// Ekranda okunacak tam ad. "GGD" çoğu kişiye bir şey ifade etmiyor.
    func compassName(for degrees: Double) -> String {
        let names = ["Kuzey", "Kuzey-kuzeydoğu", "Kuzeydoğu", "Doğu-kuzeydoğu",
                     "Doğu", "Doğu-güneydoğu", "Güneydoğu", "Güney-güneydoğu",
                     "Güney", "Güney-güneybatı", "Güneybatı", "Batı-güneybatı",
                     "Batı", "Batı-kuzeybatı", "Kuzeybatı", "Kuzey-kuzeybatı"]
        return names[sector(for: degrees) % names.count]
    }

    private func sector(for degrees: Double) -> Int {
        Int(Deg.wrap(degrees + 11.25, max: 360) / 22.5)
    }
}
