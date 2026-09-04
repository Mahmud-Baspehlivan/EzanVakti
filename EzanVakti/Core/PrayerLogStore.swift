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
        let loaded = Self.load(from: self.fileURL)
        self.snapshot = loaded.snapshot
        self.lastReadError = loaded.readError
    }

    // MARK: - Günlük takip

    func status(for prayer: Prayer, on day: Date) -> PrayerStatus {
        snapshot.days[key(for: day)]?[prayer] ?? .unmarked
    }

    /// `at` dışarıdan verilebiliyor: saatten gelen işaret telefona geç ulaşsa da
    /// kayda **konduğu** anla giriyor, yoksa gecikmiş bir işaret her seferinde
    /// en yeni karar gibi görünürdü.
    func setStatus(_ status: PrayerStatus, for prayer: Prayer, on day: Date, at markedAt: Date = Date()) {
        setStatus(status, for: prayer, dayKey: key(for: day), at: markedAt)
    }

    private func setStatus(_ status: PrayerStatus, for prayer: Prayer, dayKey: String, at markedAt: Date) {
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
        snapshot.markedAt[dayKey, default: [:]][prayer] = markedAt
        persist()
    }

    func advanceStatus(for prayer: Prayer, on day: Date) {
        setStatus(status(for: prayer, on: day).next, for: prayer, on: day)
    }

    // MARK: - Saatle eşleşme

    /// Saatten gelen işareti uygular. Uygulanmadıysa `false` döner.
    ///
    /// Tek kural: **sonra işaretlenen kazanır.** Saat çevrimdışıyken konan
    /// işaret saatler sonra ulaşabiliyor; geliş sırasına güvenmek, bu arada
    /// telefondan verilmiş daha yeni bir kararı sessizce geri alırdı.
    ///
    /// Eşitlik uygulanıyor sayılıyor: aynı işaret ikinci kez ulaşırsa (kuyruk
    /// yeniden gönderirse) sonuç değişmiyor, reddetmenin bir faydası yok.
    @discardableResult
    func apply(_ mark: PrayerMark) -> Bool {
        if let existing = snapshot.markedAt[mark.dayKey]?[mark.prayer], existing > mark.markedAt {
            return false
        }
        setStatus(mark.status, for: mark.prayer, dayKey: mark.dayKey, at: mark.markedAt)
        return true
    }

    /// Saate gönderilecek özet: bugünden geriye `dayCount` günün işaretleri.
    func digest(dayCount: Int, endingAt end: Date = Date(), generatedAt: Date = Date()) -> PrayerLogDigest {
        var days: [String: [Prayer: PrayerStatus]] = [:]
        for day in recentDays(count: dayCount, ending: end) {
            let dayKey = key(for: day)
            // Boş günler de yazılıyor: saatteki bekleyen işaret ancak telefonun
            // o gün için ne dediğini görünce düşürülebiliyor, sessizlik "haber
            // yok" ile "işaret kaldırıldı"yı ayırt ettirmiyor.
            days[dayKey] = snapshot.days[dayKey] ?? [:]
        }
        return PrayerLogDigest(days: days, generatedAt: generatedAt)
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

    /// Türetilmiş kaçırılan sayıları bir sonraki yazmaya kadar tutar.
    ///
    /// Borç hâlâ kayıttan türetiliyor — sayaç tutulmuyor — sadece aynı tarama
    /// tekrarlanmıyor. Observation'a kapalı: bu bir görünüm durumu değil,
    /// snapshot'ın kendisinden hesaplanan geçici bir ara sonuç.
    @ObservationIgnored private var missedCache: [Prayer: Int]?

    /// Günlük takipte "kılmadım" işaretlenenler; kayıttan türetiliyor, ayrıca
    /// sayaç tutulmuyor ki işaret geri alındığında borç da kendiliğinden düşsün.
    ///
    /// Tek bir ekran çizimi bu sorguyu onlarca kez yapıyor (qadaBalance →
    /// totalQada → her vakit için ayrı ayrı) ve kayıtlar budanmadığı için tarama
    /// yıllarla birlikte büyüyor. Bu yüzden tüm vakitler tek geçişte sayılıyor.
    func missedCount(for prayer: Prayer) -> Int {
        // Önbellek dolu olsa bile snapshot'a dokunuyoruz: Observation bağımlılığı
        // okuma anında kuruluyor, dokunmazsak kayıt değişince görünüm yenilenmez.
        let days = snapshot.days
        if let missedCache { return missedCache[prayer] ?? 0 }

        var counts: [Prayer: Int] = [:]
        for statuses in days.values {
            for (missed, status) in statuses where status == .missed {
                counts[missed, default: 0] += 1
            }
        }
        missedCache = counts
        return counts[prayer] ?? 0
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

    /// Anahtar üretimi `PrayerDay`'de: saat de aynı biçimi üretmek zorunda,
    /// iki yerde ayrı yazılırsa bir gün ayrışırlar.
    private func key(for day: Date) -> String { PrayerDay.key(for: day, in: calendar) }

    /// Kayıt her değiştiğinde çağrılıyor — saate gönderilen özeti tazelemek için.
    /// Mağaza `WatchConnectivity`'yi tanımıyor; bağlantıyı kuran taraf dinliyor.
    @ObservationIgnored var onChange: (() -> Void)?

    private func persist() {
        // Kayıt değişti; türetilmiş sayılar artık geçersiz. Snapshot private(set)
        // ve onu değiştiren her yol (setStatus, setOpeningQada, payQada,
        // undoQadaPayment) buraya uğradığı için geçersizleştirme tek noktada duruyor.
        missedCache = nil
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
        onChange?()
    }

    private(set) var lastWriteError: String?

    /// Okuma hatası da yazma hatası kadar görünür olmalı: kullanıcı geçmişinin
    /// neden boş göründüğünü ancak böyle öğrenebilir.
    private(set) var lastReadError: String?

    /// Kayıt dosyasını okur.
    ///
    /// "Dosya yok" ile "dosya var ama çözülemiyor" ayrı sonuçlar; ikisini boş
    /// kayıtta birleştirmek ölümcüldü: ilk dokunuş persist() çağırıp bozuk
    /// dosyanın üzerine yazıyor, aylarca birikmiş takip ve kaza borcu geri
    /// dönülmez biçimde gidiyordu. Bu yüzden çözülemeyen dosya üzerine
    /// yazılmadan önce kenara alınıyor ve hata yüzeye çıkarılıyor.
    private static func load(from url: URL) -> (snapshot: PrayerLogSnapshot, readError: String?) {
        // İlk açılışta dosyanın olmaması hata değil, normal başlangıç.
        guard FileManager.default.fileExists(atPath: url.path) else {
            return (PrayerLogSnapshot(), nil)
        }
        do {
            let data = try Data(contentsOf: url)
            return (try JSONDecoder().decode(PrayerLogSnapshot.self, from: data), nil)
        } catch {
            return (PrayerLogSnapshot(), quarantine(url, reason: error))
        }
    }

    /// Okunamayan dosyayı yanına taşır; persist() böylece boş kaydı temiz bir
    /// dosyaya yazar ve elde kalan kopya verinin kurtarılabildiği tek yer olur.
    private static func quarantine(_ url: URL, reason: Error) -> String {
        let backup = url.deletingPathExtension().appendingPathExtension("corrupt.json")
        do {
            // Önceki bir yedek varsa yerini yenisi alır: ikisi de çözülemiyor,
            // saklanacaksa en yenisi anlamlı.
            try? FileManager.default.removeItem(at: backup)
            try FileManager.default.moveItem(at: url, to: backup)
            return "Kayıt dosyası okunamadı (\(reason.localizedDescription)). "
                + "Bozuk dosya \(backup.lastPathComponent) adıyla saklandı."
        } catch {
            return "Kayıt dosyası okunamadı (\(reason.localizedDescription)) ve "
                + "kenara alınamadı (\(error.localizedDescription)); üzerine yazılabilir."
        }
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("prayer-log.json")
    }
}
