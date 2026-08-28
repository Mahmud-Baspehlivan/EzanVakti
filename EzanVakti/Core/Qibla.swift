import Foundation

enum Qibla {
    /// Kâbe'ye büyük daire üzerinden ilk yön açısı: kuzeyden saat yönünde derece.
    static func direction(from coordinate: Coordinate) -> Double {
        let longitudeDelta = Coordinate.kaaba.longitude - coordinate.longitude
        let term1 = Deg.sin(longitudeDelta)
        let term2 = Deg.cos(coordinate.latitude) * Deg.tan(Coordinate.kaaba.latitude)
        let term3 = Deg.sin(coordinate.latitude) * Deg.cos(longitudeDelta)
        return Deg.wrap(Deg.atan2(term1, term2 - term3), max: 360)
    }

    /// Kâbe'ye büyük daire uzaklığı (km). Hesap `Coordinate.distance(to:)`'da;
    /// aynı formülü iki yerde tutmak ikisinin ayrışmasına davetiye.
    static func distanceToKaaba(from coordinate: Coordinate) -> Double {
        coordinate.distance(to: .kaaba) / 1_000
    }

    /// Güneşin o andaki konumu: azimut kuzeyden saat yönünde, irtifa ufuktan derece.
    struct SolarPosition {
        let azimuth: Double
        let altitude: Double

        var isAboveHorizon: Bool { altitude > 0 }
    }

    static func solarPosition(at date: Date, from coordinate: Coordinate) -> SolarPosition {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let utcHours = Double(parts.hour ?? 0)
            + Double(parts.minute ?? 0) / 60
            + Double(parts.second ?? 0) / 3600

        let jd = Deg.julianDay(year: parts.year!, month: parts.month!, day: parts.day!) + utcHours / 24
        let sun = SunPosition(julianDay: jd)

        let solarTime = utcHours + sun.equationOfTime + coordinate.longitude / 15
        let hourAngle = 15 * (solarTime - 12)

        // Güneyden ölçülen açı; kuzey referansına çeviriyoruz.
        let fromSouth = Deg.atan2(
            Deg.sin(hourAngle),
            Deg.cos(hourAngle) * Deg.sin(coordinate.latitude)
                - Deg.tan(sun.declination) * Deg.cos(coordinate.latitude)
        )
        let altitude = Deg.asin(
            Deg.sin(coordinate.latitude) * Deg.sin(sun.declination)
                + Deg.cos(coordinate.latitude) * Deg.cos(sun.declination) * Deg.cos(hourAngle)
        )
        return SolarPosition(azimuth: Deg.wrap(180 + fromSouth, max: 360), altitude: altitude)
    }

    static func solarAzimuth(at date: Date, from coordinate: Coordinate) -> Double {
        solarPosition(at: date, from: coordinate).azimuth
    }

    /// Güneşin kıble yönüne geldiği an — gölgeye bakarak kıbleyi pusulasız doğrulamaya yarar.
    ///
    /// Analitik çözüm yerine tarama + ikiye bölme kullanıyoruz: azimut fonksiyonu
    /// gün içinde tek yönlü değil, kutup yakınlarında hiç kesişmiyor ve bazı
    /// enlemlerde günde iki kez kesişiyor. Sayısal arama bu üç durumu da doğru veriyor.
    static func qiblaTimes(on day: Date, coordinate: Coordinate, timeZone: TimeZone) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let midnight = calendar.startOfDay(for: day)
        let target = direction(from: coordinate)

        /// Hedef yöne işaretli açı farkı, ±180 aralığında.
        func delta(_ minutesFromMidnight: Double) -> Double {
            let date = midnight.addingTimeInterval(minutesFromMidnight * 60)
            var diff = solarAzimuth(at: date, from: coordinate) - target
            if diff > 180 { diff -= 360 } else if diff < -180 { diff += 360 }
            return diff
        }

        var results: [Date] = []
        var previous = delta(0)

        for minute in 1...(24 * 60) {
            let current = delta(Double(minute))
            // Azimut 0/360 sınırından atlarken yapay işaret değişimi olabiliyor;
            // sıçrama büyükse gerçek kesişim değil.
            if previous.sign != current.sign, abs(current - previous) < 180 {
                var low = Double(minute - 1)
                var high = Double(minute)
                for _ in 0..<24 {
                    let mid = (low + high) / 2
                    if delta(mid).sign == previous.sign { low = mid } else { high = mid }
                }
                let hit = midnight.addingTimeInterval((low + high) / 2 * 60)
                // Azimut gece de hesaplanıyor; güneş ufkun altındayken gölge
                // olmadığı için o kesişim kıble saati değil.
                if solarPosition(at: hit, from: coordinate).isAboveHorizon {
                    results.append(hit)
                }
            }
            previous = current
        }
        return results
    }
}
