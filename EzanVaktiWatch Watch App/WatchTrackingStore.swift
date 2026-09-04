import Foundation
import Observation
import WatchConnectivity

/// Saatteki namaz işaretleri.
///
/// Burada **kayıt tutulmuyor.** Doğruluk kaynağı telefondaki `PrayerLogStore`;
/// bu sınıf iki şey yapıyor: telefonun gönderdiği özeti gösteriyor ve bilekte
/// konan işareti telefona iletiyor. Saatte ikinci bir kayıt dosyası tutulsaydı
/// iki dosyayı birleştirme sorunu doğardı — seri, kaza borcu ve geçmiş tek
/// yerde durduğu sürece o sorun hiç ortaya çıkmıyor.
///
/// Kuyruk yine de gerekiyor: telefon uzaktayken de işaret konabilmeli. Konan
/// işaret hem `transferUserInfo` ile sisteme (teslimi garanti) hem de burada
/// "bekliyor" olarak duruyor; ekranın telefonu beklemeden doğruyu göstermesi
/// için.
@Observable
final class WatchTrackingStore: NSObject, WCSessionDelegate {
    /// Telefondan gelen özet: gün anahtarı → vakit → durum.
    private(set) var days: [String: [Prayer: PrayerStatus]] = [:]
    /// Telefonun henüz onaylamadığı işaretler.
    private(set) var pending: [PendingMark] = []
    private(set) var lastError: String?

    /// Kuyruk üst sınırı. Telefon hiç ulaşılamıyorsa (uygulama silinmiş, saat
    /// haftalarca tek başına) kuyruk sınırsız büyümesin; en eskiler düşüyor
    /// çünkü ekranda anlamı olan bugünün işaretleri.
    private static let pendingLimit = 40
    private static let storageKey = "ezan.pendingMarks.v1"

    /// `.autoupdatingCurrent`: saat günlerce açık kalıyor, donmuş bir kopya
    /// dilim değişince işareti yanlış güne yazardı.
    var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()
        pending = Self.loadPending(from: defaults)
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Okuma

    func dayKey(for day: Date) -> String { PrayerDay.key(for: day, in: calendar) }

    /// Bir vaktin görünen durumu.
    ///
    /// Bekleyen işaret telefonun söylediğini örtüyor: kullanıcı az önce
    /// dokunduysa ekranda onun kararı durmalı, telefon henüz duymamış olsa bile.
    func entry(for prayer: Prayer, on day: Date) -> (status: PrayerStatus, isPending: Bool) {
        let key = dayKey(for: day)
        if let waiting = pending.last(where: { $0.mark.dayKey == key && $0.mark.prayer == prayer }) {
            return (waiting.mark.status, true)
        }
        return (days[key]?[prayer] ?? .unmarked, false)
    }

    // MARK: - İşaretleme

    func mark(_ status: PrayerStatus, for prayer: Prayer, on day: Date, at now: Date = Date()) {
        let mark = PrayerMark(dayKey: dayKey(for: day), prayer: prayer,
                              status: status, markedAt: now)
        // Aynı vakit için bekleyen eski işaret düşüyor: kuyrukta iki karar
        // birikirse ekran hangisini göstereceğini bilemez.
        pending.removeAll { $0.mark.dayKey == mark.dayKey && $0.mark.prayer == mark.prayer }
        pending.append(PendingMark(mark: mark, isSent: false))
        if pending.count > Self.pendingLimit { pending.removeFirst(pending.count - Self.pendingLimit) }
        savePending()
        flush()
    }

    /// Henüz gönderilmemiş işaretleri sisteme teslim eder.
    ///
    /// Gönderilmiş olanlar tekrar yollanmıyor: `transferUserInfo` kuyruğu
    /// uygulama kapansa da yaşıyor, aynı işareti her açılışta yeniden koymak
    /// yalnız kuyruğu şişirirdi.
    private func flush() {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated else { return }
        for index in pending.indices where !pending[index].isSent {
            do {
                let data = try JSONEncoder().encode(PrayerMarkBatch(marks: [pending[index].mark]))
                session.transferUserInfo(PrayerSyncEnvelope.wrap(data, as: PrayerSyncEnvelope.marksKey))
                pending[index].isSent = true
            } catch {
                lastError = "İşaret gönderilemedi: \(error.localizedDescription)"
            }
        }
        savePending()
    }

    // MARK: - Telefondan gelen

    private func receive(_ data: Data?) {
        guard let data,
              let digest = try? JSONDecoder().decode(PrayerLogDigest.self, from: data) else { return }
        days = digest.days
        // Özetten önce işaretlenenler düşüyor: telefon o işareti ya uygulamış ya
        // da daha yeni bir kararla geçersiz kılmış oluyor — iki durumda da
        // ekranda gösterilecek doğru değer artık özette.
        //
        // Telefon işareti henüz almadan özet üretmişse (kendi ekranından bir
        // işaret konmuşsa) bekleyen kayıt erken düşüyor; ekran bir süre telefonun
        // değerini gösteriyor, işaret ulaşınca gelen yeni özetle kendini
        // düzeltiyor. Kaybolan bir şey yok, teslimi sistem üstlenmiş durumda.
        //
        // `isSent` koşulu tam da bunun için: teslim edilmemiş işaretin arkasında
        // sistem kuyruğu yok, onu buradan düşürmek gerçekten silmek olurdu.
        // Oturum etkinleşmeden önce işaretlenip henüz gönderilememiş bir kayıt,
        // etkinleşme anında okunan eski bağlamla tam bu yoldan kaybolabiliyordu.
        pending.removeAll { $0.isSent && $0.mark.markedAt <= digest.generatedAt }
        savePending()
    }

    // MARK: - Saklama

    private func savePending() {
        defaults.set(try? JSONEncoder().encode(pending), forKey: Self.storageKey)
    }

    private static func loadPending(from defaults: UserDefaults) -> [PendingMark] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([PendingMark].self, from: data)) ?? []
    }

    // MARK: - WCSessionDelegate

    // Temsilci çağrıları arka plan kuyruğundan geliyor; durum ana aktöre bağlı.
    // Yük burada çözülüp ana aktöre yalnızca değer tipi geçiyor.
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: (any Error)?) {
        let message = error?.localizedDescription
        // Etkinleşmeden önce gönderilen son bağlam burada duruyor; sistem
        // sakladığı için saat kapalıyken konan işaretler de karşılanıyor.
        let stored = PrayerSyncEnvelope.payload(from: session.receivedApplicationContext,
                                                as: PrayerSyncEnvelope.digestKey)
        Task { @MainActor in
            if let message { self.lastError = "Telefon bağlantısı kurulamadı: \(message)" }
            self.receive(stored)
            self.flush()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        let data = PrayerSyncEnvelope.payload(from: context, as: PrayerSyncEnvelope.digestKey)
        Task { @MainActor in self.receive(data) }
    }
}

/// Kuyruktaki bir işaret. `isSent`, sistemin teslim kuyruğuna verilip
/// verilmediğini söylüyor — telefonun onayı ayrı bir şey, o gelince kayıt
/// tamamen düşüyor.
struct PendingMark: Codable, Equatable, Sendable {
    let mark: PrayerMark
    var isSent: Bool
}
