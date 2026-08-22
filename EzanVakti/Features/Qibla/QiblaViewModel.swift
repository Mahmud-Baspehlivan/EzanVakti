import Foundation
import Observation

@Observable
final class QiblaViewModel {
    private(set) var coordinate: Coordinate = .istanbul
    var timeZone: TimeZone = .current

    /// Pusula okumasının kıbleye oturduğu kabul edilen tolerans.
    static let alignmentTolerance: Double = 5

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
        Qibla.qiblaTimes(on: day, coordinate: coordinate, timeZone: timeZone)
    }

    /// Diyanet kıble saatini dakikaya yukarı yuvarlıyor; ölçtüğümüz 17 günün
    /// 14'ünde bu kural birebir tutuyor, kalanında sapma 1 dakika.
    func formattedMinute(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let seconds = calendar.component(.second, from: date)
        let rounded = seconds > 0 ? date.addingTimeInterval(Double(60 - seconds)) : date

        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: rounded)
    }

    var distanceText: String {
        let km = Qibla.distanceToKaaba(from: coordinate)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.maximumFractionDigits = 0
        return (formatter.string(from: NSNumber(value: km)) ?? "\(Int(km))") + " km"
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
        Int(wrap(degrees + 11.25, max: 360) / 22.5)
    }
}
