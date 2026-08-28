import Foundation

/// Astronomik formüller derece cinsinden yazıldığı için radyan dönüşümünü
/// tek yerde toplayan yardımcı katman.
enum Deg {
    static func sin(_ d: Double) -> Double { Foundation.sin(d * .pi / 180) }
    static func cos(_ d: Double) -> Double { Foundation.cos(d * .pi / 180) }
    static func tan(_ d: Double) -> Double { Foundation.tan(d * .pi / 180) }
    static func asin(_ x: Double) -> Double { Foundation.asin(x) * 180 / .pi }
    static func acos(_ x: Double) -> Double { Foundation.acos(x) * 180 / .pi }
    static func atan2(_ y: Double, _ x: Double) -> Double { Foundation.atan2(y, x) * 180 / .pi }
    static func acot(_ x: Double) -> Double { Foundation.atan(1 / x) * 180 / .pi }

    /// Açıyı [0, max) aralığına katlar.
    static func wrap(_ value: Double, max: Double) -> Double {
        let r = value.truncatingRemainder(dividingBy: max)
        return r < 0 ? r + max : r
    }

    /// Takvim tarihinden Jülyen günü.
    static func julianDay(year: Int, month: Int, day: Int) -> Double {
        var y = year, m = month
        if m <= 2 { y -= 1; m += 12 }
        let a = (Double(y) / 100).rounded(.down)
        let b = 2 - a + (a / 4).rounded(.down)
        return (365.25 * (Double(y) + 4716)).rounded(.down)
            + (30.6001 * (Double(m) + 1)).rounded(.down)
            + Double(day) + b - 1524.5
    }
}

/// Güneşin verilen Jülyen gününde deklinasyonu ve zaman denklemi.
/// USNO yaklaşık formülleri — dakika altı hassasiyet, namaz vakti için fazlasıyla yeterli.
struct SunPosition {
    let declination: Double     // derece
    let equationOfTime: Double  // saat

    init(julianDay jd: Double) {
        let d = jd - 2_451_545.0
        let meanAnomaly = Deg.wrap(357.529 + 0.985_600_28 * d, max: 360)
        let meanLongitude = Deg.wrap(280.459 + 0.985_647_36 * d, max: 360)
        let eclipticLongitude = Deg.wrap(
            meanLongitude + 1.915 * Deg.sin(meanAnomaly) + 0.020 * Deg.sin(2 * meanAnomaly),
            max: 360
        )
        let obliquity = 23.439 - 0.000_000_36 * d

        let rightAscension = Deg.wrap(
            Deg.atan2(Deg.cos(obliquity) * Deg.sin(eclipticLongitude), Deg.cos(eclipticLongitude)) / 15,
            max: 24
        )

        declination = Deg.asin(Deg.sin(obliquity) * Deg.sin(eclipticLongitude))

        // Gün dönümü sınırında q/15 ile RA farklı taraflara sarabiliyor; ±12 saate katla.
        var eqt = meanLongitude / 15 - rightAscension
        if eqt > 12 { eqt -= 24 } else if eqt < -12 { eqt += 24 }
        equationOfTime = eqt
    }
}

