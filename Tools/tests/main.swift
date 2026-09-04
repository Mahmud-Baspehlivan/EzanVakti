import Foundation

// Basit test kosucusu: XCTest'e ihtiyac duymadan swiftc ile calisiyor.
var failures = 0
var checks = 0

func check(_ condition: Bool, _ label: String) {
    checks += 1
    if !condition { failures += 1; print("  BASARISIZ: \(label)") }
}

func equal<T: Equatable>(_ actual: T, _ expected: T, _ label: String) {
    checks += 1
    if actual != expected {
        failures += 1
        print("  BASARISIZ: \(label) — beklenen \(expected), gelen \(actual)")
    }
}

func section(_ title: String) { print("\n== \(title) ==") }

let tz = TimeZone(identifier: "Europe/Istanbul")!
var cal = Calendar(identifier: .gregorian)
cal.timeZone = tz
func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
    cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
}

func makeStore(_ name: String) -> PrayerLogStore {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("ezan-test-\(name).json")
    try? FileManager.default.removeItem(at: url)
    return PrayerLogStore(fileURL: url, timeZone: tz)
}

// MARK: - Günlük takip

section("gunluk takip")
do {
    let store = makeStore("daily")
    let d = day(2026, 8, 20)

    equal(store.status(for: .ogle, on: d), .unmarked, "baslangicta isaretsiz")

    store.setStatus(.performed, for: .ogle, on: d)
    equal(store.status(for: .ogle, on: d), .performed, "kaydedilen durum okunuyor")
    equal(store.status(for: .ikindi, on: d), .unmarked, "diger vakit etkilenmiyor")

    store.setStatus(.unmarked, for: .ogle, on: d)
    equal(store.status(for: .ogle, on: d), .unmarked, "isaret geri alinabiliyor")
    check(store.snapshot.days["2026-08-20"] == nil, "bos gun kaydi temizleniyor")

    // dokundukca sirayla gecis
    store.advanceStatus(for: .aksam, on: d)
    equal(store.status(for: .aksam, on: d), .performed, "1. dokunus: kildim")
    store.advanceStatus(for: .aksam, on: d)
    equal(store.status(for: .aksam, on: d), .congregation, "2. dokunus: cemaatle")
    store.advanceStatus(for: .aksam, on: d)
    equal(store.status(for: .aksam, on: d), .missed, "3. dokunus: kilmadim")
    store.advanceStatus(for: .aksam, on: d)
    equal(store.status(for: .aksam, on: d), .unmarked, "4. dokunus: basa donuyor")
}

// MARK: - Tamamlanma ve seri

section("tamamlanma ve seri")
do {
    let store = makeStore("streak")
    let today = day(2026, 8, 22)

    func fill(_ d: Date, _ status: PrayerStatus = .performed) {
        for p in PrayerLogStore.trackedPrayers { store.setStatus(status, for: p, on: d) }
    }

    check(!store.isComplete(today), "bos gun tamamlanmis sayilmiyor")
    fill(today)
    check(store.isComplete(today), "5 vakit kilinca gun tamam")
    equal(store.performedCount(on: today), 5, "kilinan sayisi")

    // Gunes takip edilmiyor
    store.setStatus(.performed, for: .gunes, on: today)
    equal(store.performedCount(on: today), 5, "Gunes sayima girmiyor")

    fill(cal.date(byAdding: .day, value: -1, to: today)!)
    fill(cal.date(byAdding: .day, value: -2, to: today)!, .congregation)
    equal(store.currentStreak(today: today), 3, "cemaat de seriye sayiliyor")

    // bugun eksikse seri dunden sayilir
    let store2 = makeStore("streak2")
    fill2(store2, cal.date(byAdding: .day, value: -1, to: today)!)
    fill2(store2, cal.date(byAdding: .day, value: -2, to: today)!)
    store2.setStatus(.performed, for: .imsak, on: today)   // bugun yarim
    equal(store2.currentStreak(today: today), 2, "bugun yarimken seri dunden sayiliyor")

    let store3 = makeStore("streak3")
    equal(store3.currentStreak(today: today), 0, "hic kayit yokken seri sifir")
}

func fill2(_ store: PrayerLogStore, _ d: Date, _ status: PrayerStatus = .performed) {
    for p in PrayerLogStore.trackedPrayers { store.setStatus(status, for: p, on: d) }
}

// MARK: - Kaza

section("kaza borcu")
do {
    let store = makeStore("qada")
    let d = day(2026, 8, 20)

    equal(store.qadaBalance(for: .ogle), 0, "baslangicta borc yok")

    store.setOpeningQada(10, for: .ogle)
    equal(store.qadaBalance(for: .ogle), 10, "eski borc giriliyor")

    store.setStatus(.missed, for: .ogle, on: d)
    equal(store.qadaBalance(for: .ogle), 11, "kilmadim isareti borca ekleniyor")

    store.payQada(for: .ogle)
    equal(store.qadaBalance(for: .ogle), 10, "kaza kilinca borc dusuyor")

    // cift sayma olmamali: isaret geri alininca borc da geri gitmeli
    store.setStatus(.performed, for: .ogle, on: d)
    equal(store.qadaBalance(for: .ogle), 9, "isaret duzeltilince borc da duzeliyor")

    store.setOpeningQada(0, for: .ogle)
    equal(store.qadaBalance(for: .ogle), 0, "borc negatife dusmuyor")
    store.payQada(for: .ogle)
    equal(store.qadaBalance(for: .ogle), 0, "borc yokken odeme yok sayiliyor")

    store.setOpeningQada(3, for: .imsak)
    store.setOpeningQada(2, for: .yatsi)
    equal(store.totalQada, 5, "toplam borc")

    store.payQada(for: .imsak)
    store.undoQadaPayment(for: .imsak)
    equal(store.qadaBalance(for: .imsak), 3, "yanlis odeme geri alinabiliyor")
}

// MARK: - Kalan süre biçimi

section("kalan sure bicimi")
do {
    let now = day(2026, 8, 24)
    func readout(_ seconds: Int, showsSeconds: Bool = true) -> RemainingReadout? {
        RemainingTime.readout(to: now.addingTimeInterval(TimeInterval(seconds)),
                              at: now, showsSeconds: showsSeconds)
    }
    func shown(_ seconds: Int, showsSeconds: Bool = true) -> String {
        readout(seconds, showsSeconds: showsSeconds)?
            .parts.map { $0.value + $0.unit }.joined(separator: " ") ?? "-"
    }

    equal(shown(6 * 3600 + 21 * 60 + 40), "6sa 21dk", "bir saatin ustunde saat + dakika")
    equal(shown(3600), "1sa 0dk", "tam saatte dakika da yaziliyor, genislik oynamasin")
    equal(shown(47 * 60), "47dk", "on dakika - bir saat arasi tek birim")
    equal(shown(600), "10dk", "esikte hala dakika")
    equal(shown(599), "9dk 59sn", "esigin altinda saniye de yaziliyor")
    equal(shown(45), "45sn", "bir dakikanin altinda tek birim")
    equal(shown(0), "0sn", "vakit girdiginde sifir")

    // Saat tarafi esigin altinda sistemin sayacina birakiyor.
    check(readout(599, showsSeconds: false) == nil, "saatte esigin altinda nil donuyor")
    check(readout(600, showsSeconds: false) != nil, "saatte esigin ustunde deger donuyor")

    // VoiceOver kisaltmasiz okuyor.
    equal(readout(6 * 3600 + 21 * 60)?.spoken, "6 saat 21 dakika", "sesli hal kisaltmasiz")
    equal(readout(47 * 60)?.spoken, "47 dakika", "tek birimde de kisaltmasiz")
}

// MARK: - İşaretleme penceresi

section("isaretleme penceresi")
do {
    // Ogle 13:00, ikindi 16:30, yatsi 21:00 olan uydurma bir gun.
    let d = day(2026, 8, 24)
    func at(_ hour: Int, _ minute: Int) -> Date {
        cal.date(bySettingHour: hour, minute: minute, second: 0, of: d)!
    }
    let times = DailyPrayerTimes(
        day: d,
        times: [.imsak: at(4, 30), .gunes: at(6, 10), .ogle: at(13, 0),
                .ikindi: at(16, 30), .aksam: at(19, 50), .yatsi: at(21, 0)],
        trueSunrise: at(6, 10), trueSunset: at(19, 50))!

    let noon = at(13, 30)   // ogle vakti icindeyiz

    check(PrayerMarking.isMarkable(.ogle, on: d, times: times, now: noon, calendar: cal),
          "vakti girmis namaz isaretlenebiliyor")
    check(!PrayerMarking.isMarkable(.yatsi, on: d, times: times, now: noon, calendar: cal),
          "ogle vaktindeyken yatsi isaretlenemiyor")
    check(PrayerMarking.isMarkable(.imsak, on: d, times: times, now: noon, calendar: cal),
          "gunun gecmis vakti isaretlenebiliyor")

    // Tam vaktin girdigi an isaretlenebilir olmali.
    check(PrayerMarking.isMarkable(.ikindi, on: d, times: times, now: at(16, 30), calendar: cal),
          "vaktin girdigi an isaretlenebiliyor")
    check(!PrayerMarking.isMarkable(.ikindi, on: d, times: times, now: at(16, 29), calendar: cal),
          "bir dakika oncesi isaretlenemiyor")

    // Gecmis gunun tamami acik, gelecek gun tamamen kapali.
    let yesterday = day(2026, 8, 23)
    let tomorrow = day(2026, 8, 25)
    check(PrayerMarking.isMarkable(.yatsi, on: yesterday, times: nil, now: noon, calendar: cal),
          "gecmis gunun butun vakitleri isaretlenebiliyor")
    check(!PrayerMarking.isMarkable(.imsak, on: tomorrow, times: nil, now: noon, calendar: cal),
          "gelecek gun isaretlenemiyor")

    // Vakitler hesaplanamiyorsa engellemek yerine izin veriliyor.
    check(PrayerMarking.isMarkable(.yatsi, on: d, times: nil, now: noon, calendar: cal),
          "vakit hesaplanamiyorsa isaretlemeye izin veriliyor")
}

// MARK: - Saatle eşleşme

section("saat esitleme")
do {
    let store = makeStore("sync")
    let d = day(2026, 8, 24)
    let key = "2026-08-24"
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    equal(PrayerDay.key(for: d, in: cal), key,
          "saat ve telefon ayni gun anahtarini uretiyor")

    check(store.apply(PrayerMark(dayKey: key, prayer: .ogle, status: .congregation, markedAt: t0)),
          "saatten gelen isaret uygulaniyor")
    equal(store.status(for: .ogle, on: d), .congregation, "durum kayda gecti")

    // Gecikmis isaret daha yeni karari ezmemeli: saat cevrimdisiyken konan
    // isaret saatler sonra ulasabiliyor.
    store.setStatus(.performed, for: .ogle, on: d, at: t0.addingTimeInterval(60))
    check(!store.apply(PrayerMark(dayKey: key, prayer: .ogle, status: .missed,
                                  markedAt: t0.addingTimeInterval(30))),
          "eski isaret reddediliyor")
    equal(store.status(for: .ogle, on: d), .performed, "telefondaki yeni karar korunuyor")

    // Ayni isaret ikinci kez ulasirsa sonuc degismemeli.
    let repeated = PrayerMark(dayKey: key, prayer: .ikindi, status: .performed, markedAt: t0)
    check(store.apply(repeated), "ilk gelis uygulaniyor")
    check(store.apply(repeated), "ayni isaret tekrar gelince de uygulaniyor")
    equal(store.status(for: .ikindi, on: d), .performed, "tekrar sonucu degistirmiyor")

    // "Isareti kaldir" da bir karar; ondan onceki isaret geri getirmemeli.
    store.apply(PrayerMark(dayKey: key, prayer: .ikindi, status: .unmarked,
                           markedAt: t0.addingTimeInterval(120)))
    equal(store.status(for: .ikindi, on: d), .unmarked, "kaldirma uygulaniyor")
    check(!store.apply(PrayerMark(dayKey: key, prayer: .ikindi, status: .performed,
                                  markedAt: t0.addingTimeInterval(90))),
          "kaldirmadan onceki isaret reddediliyor")
    equal(store.status(for: .ikindi, on: d), .unmarked, "kaldirma korunuyor")

    let digest = store.digest(dayCount: 3, endingAt: d, generatedAt: t0)
    equal(digest.days.count, 3, "ozet istenen gun sayisini tasiyor")
    equal(digest.days[key]?[.ogle], .performed, "ozet bugunun isaretini tasiyor")
    check(digest.days["2026-08-23"] != nil, "isaretsiz gun de ozette yaziyor")
    equal(digest.generatedAt, t0, "ozetin uretim ani tasiniyor")
}

// MARK: - Eski kayıt dosyası

section("eski kayit dosyasi")
do {
    // `markedAt` alani eklenmeden once yazilmis bir dosya. Sentezlenen cozucu
    // eksik anahtari hata sayardi: butun kayit karantinaya girer, kullanici
    // aylarca birikmis takibini bos ekranda bulurdu.
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("ezan-test-legacy.json")
    let legacy = #"{"days":{"2026-08-20":{"ikindi":"performed"}},"qada":{"opening":{"yatsi":4},"paid":{}}}"#
    try! Data(legacy.utf8).write(to: url)

    let store = PrayerLogStore(fileURL: url, timeZone: tz)
    check(store.lastReadError == nil, "eski dosya karantinaya alinmiyor")
    equal(store.status(for: .ikindi, on: day(2026, 8, 20)), .performed, "eski dosyadaki isaret okunuyor")
    equal(store.qadaBalance(for: .yatsi), 4, "eski dosyadaki kaza borcu okunuyor")
}

// MARK: - Kalıcılık

section("kalicilik")
do {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("ezan-test-persist.json")
    try? FileManager.default.removeItem(at: url)

    let d = day(2026, 8, 21)
    let first = PrayerLogStore(fileURL: url, timeZone: tz)
    first.setStatus(.congregation, for: .ikindi, on: d)
    first.setOpeningQada(7, for: .yatsi)
    check(first.lastWriteError == nil, "yazma hatasi yok")

    let reloaded = PrayerLogStore(fileURL: url, timeZone: tz)
    equal(reloaded.status(for: .ikindi, on: d), .congregation, "durum diskten geri okunuyor")
    equal(reloaded.qadaBalance(for: .yatsi), 7, "kaza borcu diskten geri okunuyor")

    // JSON okunabilir olmali: vakit anahtarlari nesne olarak kodlanmali
    let raw = String(data: try! Data(contentsOf: url), encoding: .utf8) ?? ""
    check(raw.contains("\"ikindi\""), "vakit anahtari JSON'da isimle duruyor")
    check(!raw.contains("[\"ikindi\""), "sozluk diziye cevrilmemis")

    let empty = PrayerLogStore(
        fileURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("yok-boyle-dosya.json"),
        timeZone: tz)
    equal(empty.totalQada, 0, "olmayan dosya bos kayitla aciliyor")
}

print("\n\(checks) kontrol, \(failures) basarisiz")
exit(failures == 0 ? 0 : 1)
