import Foundation
import Observation
import WatchConnectivity

/// Saatten gelen namaz işaretlerini kayda geçiren ve kaydın özetini saate geri
/// gönderen köprü.
///
/// Doğruluk kaynağı telefondaki `PrayerLogStore`: kaza borcu, seri ve geçmiş
/// orada duruyor, saat yalnızca işaret koyuyor. İki yönlü bir çoğaltma değil,
/// bilerek asimetrik bir akış — saatte ikinci bir kayıt dosyası tutulsaydı iki
/// dosyayı birleştirme sorunu çıkardı ve o sorunun ucuz bir çözümü yok.
///
/// İşaretler `transferUserInfo` ile gidiyor: kuyruklu ve teslimi garanti, saat
/// telefondan uzaktayken konan işaret kaybolmuyor. Özet ise
/// `updateApplicationContext` ile — orada yalnızca **son** hâl anlamlı, bekleyen
/// eskisinin üzerine yazması tam istenen şey.
@Observable
final class WatchSyncController: NSObject, WCSessionDelegate {
    /// Saate gönderilen özetin kapsadığı gün sayısı. Saatte gösterilen tek gün
    /// bugün; bir hafta, gece yarısını devirmiş ya da birkaç gün açılmamış bir
    /// saatin da doğruyu göstermesi için var.
    private static let digestDayCount = 7

    private let log: PrayerLogStore

    /// Son hata ekranda söylenebilsin diye duruyor: eşleşme sessizce
    /// çalışmıyorsa kullanıcı bunu ancak kaydı eksik bularak anlar.
    private(set) var lastError: String?
    init(log: PrayerLogStore) {
        self.log = log
        super.init()
        // iPad'de eşleşme yok; orada oturum açmak hataya düşüyor.
        guard WCSession.isSupported() else { return }
        // Kayıt her değiştiğinde özet tazeleniyor — işaret telefondan konsa da
        // saatten gelse de. Saatin gördüğü, telefonun bildiğinden geri kalmıyor.
        log.onChange = { [weak self] in self?.publishDigest() }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Kaydın son hâlini saate yollar.
    ///
    /// Oturum etkin değilse sessizce çıkıyor: bağlam gönderimi kuyruklanmıyor,
    /// etkinleşme tamamlandığında zaten yeniden çağrılıyor.
    func publishDigest() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isWatchAppInstalled else { return }
        do {
            let digest = log.digest(dayCount: Self.digestDayCount)
            let data = try JSONEncoder().encode(digest)
            try session.updateApplicationContext(
                PrayerSyncEnvelope.wrap(data, as: PrayerSyncEnvelope.digestKey))
            lastError = nil
        } catch {
            lastError = "Saate gönderilemedi: \(error.localizedDescription)"
        }
    }

    private func receive(_ marks: [PrayerMark]) {
        for mark in marks { log.apply(mark) }
        // Kayıt değişmediyse (hepsi eskiydi) `onChange` tetiklenmiyor; saat yine
        // de telefonun ne bildiğini öğrenmeli, yoksa reddedilen işaret bilekte
        // sonsuza kadar "bekliyor" görünür.
        publishDigest()
    }

    // MARK: - WCSessionDelegate

    // Temsilci çağrıları arka plan kuyruğundan geliyor; mağaza ve görünüm
    // durumu ana aktöre bağlı. Yükü burada çözüp ana aktöre yalnızca değer
    // tipini geçiriyoruz — `WCSession` ve sözlüğün kendisi taşınabilir değil.
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let data = PrayerSyncEnvelope.payload(from: userInfo,
                                                    as: PrayerSyncEnvelope.marksKey) else { return }
        Task { @MainActor in
            guard let batch = try? JSONDecoder().decode(PrayerMarkBatch.self, from: data) else { return }
            self.receive(batch.marks)
        }
    }

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: (any Error)?) {
        let message = error?.localizedDescription
        Task { @MainActor in
            if let message { self.lastError = "Saat bağlantısı kurulamadı: \(message)" }
            self.publishDigest()
        }
    }

    /// Saat değiştirildiğinde (eşleşme kaldırma, yeni saat) oturum kapanıyor;
    /// yeniden etkinleştirmezsek eşleşme o cihazdan sonra hiç çalışmıyor.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Saat uygulaması yeni kurulduysa elimizdeki kaydı hemen gönderiyoruz:
    /// aksi halde bilek, ilk işaret konana kadar boş görünür.
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.publishDigest() }
    }
}
