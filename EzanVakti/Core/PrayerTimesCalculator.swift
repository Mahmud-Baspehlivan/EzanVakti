import Foundation

/// Verilen koordinat ve parametrelerle bir günün vakitlerini hesaplar.
/// Ağ bağımlılığı yok — uygulama tamamen çevrimdışı çalışır.
struct PrayerTimesCalculator {
    let coordinate: Coordinate
    let parameters: PrayerCalculationParameters

    init(coordinate: Coordinate, parameters: PrayerCalculationParameters = .diyanet) {
        self.coordinate = coordinate
        self.parameters = parameters
    }

    func times(for date: Date, in timeZone: TimeZone) -> DailyPrayerTimes? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day,
              let midnight = calendar.date(from: DateComponents(year: year, month: month, day: day))
        else { return nil }

        // Boylam kaymasını Jülyen günün içine katıyoruz (PrayTimes yaklaşımı).
        let jd = julianDay(year: year, month: month, day: day) - coordinate.longitude / (15 * 24)
        let utcOffset = Double(timeZone.secondsFromGMT(for: midnight)) / 3600
        let shift = utcOffset - coordinate.longitude / 15

        let riseSetAngle = 0.833 + 0.0347 * max(0, parameters.elevation).squareRoot()

        // Vakitler kendi anlarındaki deklinasyona bağlı; başlangıç tahminlerinden
        // birkaç tur döndürerek sabit noktaya yakınsıyoruz. Tek tur bırakıldığında
        // batış tarafında ~1 dk asimetri kalıyor.
        var portions: [Prayer: Double] = [
            .imsak: 5.0 / 24, .gunes: 6.0 / 24, .ogle: 12.0 / 24,
            .ikindi: 13.0 / 24, .aksam: 18.0 / 24, .yatsi: 18.0 / 24,
        ]
        var raw: [Prayer: Double] = [:]

        for _ in 0..<3 {
            raw = [
                .imsak:  sunAngle(parameters.fajrAngle, jd: jd, dayPortion: portions[.imsak]!, counterClockwise: true),
                .gunes:  sunAngle(riseSetAngle, jd: jd, dayPortion: portions[.gunes]!, counterClockwise: true),
                .ogle:   midDay(jd: jd, dayPortion: portions[.ogle]!),
                .ikindi: asr(jd: jd, dayPortion: portions[.ikindi]!),
                .aksam:  sunAngle(riseSetAngle, jd: jd, dayPortion: portions[.aksam]!, counterClockwise: false),
                .yatsi:  sunAngle(parameters.ishaAngle, jd: jd, dayPortion: portions[.yatsi]!, counterClockwise: false),
            ]
            // Kutup bölgelerinde sabah/yatsı hesaplanamaz; NaN'i yukarı sızdırmıyoruz.
            guard raw.values.allSatisfy({ $0.isFinite }) else { return nil }
            for (prayer, hours) in raw { portions[prayer] = hours / 24 }
        }

        for key in raw.keys { raw[key]! += shift }

        var result: [Prayer: Date] = [:]
        for (prayer, hours) in raw {
            let offset = Double(parameters.adjustments[prayer] ?? 0) * 60
            result[prayer] = midnight.addingTimeInterval(hours * 3600 + offset)
        }

        return DailyPrayerTimes(
            day: midnight,
            times: result,
            trueSunrise: midnight.addingTimeInterval(raw[.gunes]! * 3600),
            trueSunset: midnight.addingTimeInterval(raw[.aksam]! * 3600)
        )
    }

    // MARK: - Astronomi

    private func midDay(jd: Double, dayPortion t: Double) -> Double {
        wrap(12 - SunPosition(julianDay: jd + t).equationOfTime, max: 24)
    }

    private func sunAngle(_ angle: Double, jd: Double, dayPortion t: Double, counterClockwise: Bool) -> Double {
        let declination = SunPosition(julianDay: jd + t).declination
        let numerator = -Deg.sin(angle) - Deg.sin(declination) * Deg.sin(coordinate.latitude)
        let denominator = Deg.cos(declination) * Deg.cos(coordinate.latitude)
        let ratio = numerator / denominator
        guard abs(ratio) <= 1 else { return .nan }
        let hourAngle = Deg.acos(ratio) / 15
        return midDay(jd: jd, dayPortion: t) + (counterClockwise ? -hourAngle : hourAngle)
    }

    private func asr(jd: Double, dayPortion t: Double) -> Double {
        let declination = SunPosition(julianDay: jd + t).declination
        let angle = -Deg.acot(parameters.asrShadowFactor + Deg.tan(abs(coordinate.latitude - declination)))
        return sunAngle(angle, jd: jd, dayPortion: t, counterClockwise: false)
    }
}
