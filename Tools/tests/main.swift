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
