import Foundation
import Observation

/// Namaz takibi ve kaza borcunu tutar.
///
/// Veri küçük (bir yıl ≈ 1825 kayıt) olduğu için dosyaya JSON yazıyoruz.
/// SwiftData yerine bunun seçilmesinin nedeni test edilebilirlik: mağaza saf
/// Foundation olduğu için Xcode olmadan da koşulabiliyor. İleride SwiftData veya
/// CloudKit'e geçilirse değişiklik bu sınıfla sınırlı kalır.
@Observable
final class PrayerLogStore {
    private(set) var snapshot: PrayerLogSnapshot

    private let fileURL: URL
    private let calendar: Calendar

    /// Takip edilen vakitler — Güneş bir namaz vakti değil.
    static let trackedPrayers = Prayer.allCases.filter(\.isPrayer)

    init(fileURL: URL? = nil, timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.snapshot = Self.load(from: self.fileURL)
    }

    // MARK: - Günlük takip

    func status(for prayer: Prayer, on day: Date) -> PrayerStatus {
        snapshot.days[key(for: day)]?[prayer] ?? .unmarked
    }

    func setStatus(_ status: PrayerStatus, for prayer: Prayer, on day: Date) {
        let dayKey = key(for: day)
        var statuses = snapshot.days[dayKey] ?? [:]

        if status == .unmarked {
            statuses[prayer] = nil
        } else {
            statuses[prayer] = status
        }

        if statuses.isEmpty {
            snapshot.days[dayKey] = nil
        } else {
            snapshot.days[dayKey] = statuses
        }
        persist()
    }

    func advanceStatus(for prayer: Prayer, on day: Date) {
        setStatus(status(for: prayer, on: day).next, for: prayer, on: day)
    }

    func isComplete(_ day: Date) -> Bool {
        let statuses = snapshot.days[key(for: day)] ?? [:]
        return Self.trackedPrayers.allSatisfy { statuses[$0]?.countsAsPerformed == true }
    }

    func performedCount(on day: Date) -> Int {
        let statuses = snapshot.days[key(for: day)] ?? [:]
        return Self.trackedPrayers.filter { statuses[$0]?.countsAsPerformed == true }.count
    }

    /// Bugünden geriye doğru kesintisiz tam gün sayısı.
    ///
    /// Bugün henüz tamamlanmadıysa seri dünden sayılıyor; aksi halde gün ortasında
    /// uygulamayı açan herkesin serisi sıfırlanmış görünürdü.
    func currentStreak(today: Date = Date()) -> Int {
        var cursor = calendar.startOfDay(for: today)
        if !isComplete(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        while isComplete(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    func recentDays(count: Int, ending: Date = Date()) -> [Date] {
        let end = calendar.startOfDay(for: ending)
        return (0..<count).compactMap {
            calendar.date(byAdding: .day, value: -($0), to: end)
        }.reversed()
    }

    // MARK: - Kaza

    /// Günlük takipte "kılmadım" işaretlenenler; kayıttan türetiliyor, ayrıca
    /// sayaç tutulmuyor ki işaret geri alındığında borç da kendiliğinden düşsün.
    func missedCount(for prayer: Prayer) -> Int {
        snapshot.days.values.filter { $0[prayer] == .missed }.count
    }

    func qadaBalance(for prayer: Prayer) -> Int {
        let opening = snapshot.qada.opening[prayer] ?? 0
        let paid = snapshot.qada.paid[prayer] ?? 0
        return max(0, opening + missedCount(for: prayer) - paid)
    }

    var totalQada: Int {
        Self.trackedPrayers.reduce(0) { $0 + qadaBalance(for: $1) }
    }

    /// Eski birikmiş borcu ayarlar (kullanıcı elle girer).
    func setOpeningQada(_ count: Int, for prayer: Prayer) {
        snapshot.qada.opening[prayer] = max(0, count)
        persist()
    }

    /// Bir kaza namazı kılındı olarak düşer. Borç yoksa hiçbir şey yapmaz.
    func payQada(for prayer: Prayer) {
        guard qadaBalance(for: prayer) > 0 else { return }
        snapshot.qada.paid[prayer] = (snapshot.qada.paid[prayer] ?? 0) + 1
        persist()
    }

    /// Yanlışlıkla düşülen kazayı geri alır.
    func undoQadaPayment(for prayer: Prayer) {
        let paid = snapshot.qada.paid[prayer] ?? 0
        guard paid > 0 else { return }
        snapshot.qada.paid[prayer] = paid - 1
        persist()
    }

    // MARK: - Saklama

    private func key(for day: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(snapshot)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Yazma hatası sessizce yutulursa kullanıcı kaydının gittiğini fark etmez.
            lastWriteError = error.localizedDescription
        }
    }

    private(set) var lastWriteError: String?

    private static func load(from url: URL) -> PrayerLogSnapshot {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(PrayerLogSnapshot.self, from: data)
        else { return PrayerLogSnapshot() }
        return decoded
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("prayer-log.json")
    }
}
