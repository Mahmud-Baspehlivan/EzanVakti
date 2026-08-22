import Foundation

// veri.json'daki illeri okur, CIPLAK astronomik vakitleri CSV olarak yazar.
struct Il: Decodable {
    let lat: Double
    let lon: Double
}

let path = "/private/tmp/claude-501/-Users-mahmudbaspehlivan-Downloads-Repo-hw-backend/15da543f-6470-4313-a5d0-ce7cce2e0d9e/scratchpad/temkin/veri.json"
let raw = try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path))) as! [String: Any]

let tz = TimeZone(identifier: "Europe/Istanbul")!
var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
let fmt = DateFormatter(); fmt.timeZone = tz; fmt.dateFormat = "HH:mm"
let dayFmt = DateFormatter(); dayFmt.timeZone = tz; dayFmt.dateFormat = "dd.MM.yyyy"

print("il,date,imsak,gunes,ogle,ikindi,aksam,yatsi")
for (ad, any) in raw {
    guard let d = any as? [String: Any],
          let lat = d["lat"] as? Double, let lon = d["lon"] as? Double else { continue }
    let calc = PrayerTimesCalculator(coordinate: Coordinate(latitude: lat, longitude: lon),
                                     parameters: .astronomical)
    for day in 1...31 {
        guard let date = cal.date(from: DateComponents(year: 2026, month: 8, day: day)),
              let t = calc.times(for: date, in: tz) else { continue }
        let cols = Prayer.allCases.map { fmt.string(from: t[$0]) }.joined(separator: ",")
        print("\(ad),\(dayFmt.string(from: date)),\(cols)")
    }
}
