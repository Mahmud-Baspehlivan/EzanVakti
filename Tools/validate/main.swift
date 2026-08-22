import Foundation

// Dogrulama kosucusu: uygulama hedefinin disinda, cekirdegi CSV'ye doker.
let tz = TimeZone(identifier: "Europe/Istanbul")!
var cal = Calendar(identifier: .gregorian)
cal.timeZone = tz

let coordinate = Coordinate.istanbul
let calculator = PrayerTimesCalculator(coordinate: coordinate, parameters: .diyanet)

let fmt = DateFormatter(); fmt.timeZone = tz; fmt.dateFormat = "HH:mm"
let dayFmt = DateFormatter(); dayFmt.timeZone = tz; dayFmt.dateFormat = "dd.MM.yyyy"

let mode = CommandLine.arguments.dropFirst().first ?? "times"

if mode == "qibla" {
    print(String(format: "# kible yonu: %.2f derece", Qibla.direction(from: coordinate)))
    print("date,kiblesaati,kesisim_sayisi")
    for day in 1...31 {
        guard let date = cal.date(from: DateComponents(year: 2026, month: 8, day: day)) else { continue }
        let hits = Qibla.qiblaTimes(on: date, coordinate: coordinate, timeZone: tz)
        let first = hits.first.map { fmt.string(from: $0) } ?? "-"
        print("\(dayFmt.string(from: date)),\(first),\(hits.count)")
    }
} else {
    print("date,imsak,gunes,ogle,ikindi,aksam,yatsi,truesunrise,truesunset")
    for day in 1...31 {
        guard let date = cal.date(from: DateComponents(year: 2026, month: 8, day: day)),
              let t = calculator.times(for: date, in: tz) else { continue }
        let cols = Prayer.allCases.map { fmt.string(from: t[$0]) }.joined(separator: ",")
        print("\(dayFmt.string(from: date)),\(cols),\(fmt.string(from: t.trueSunrise)),\(fmt.string(from: t.trueSunset))")
    }
}
