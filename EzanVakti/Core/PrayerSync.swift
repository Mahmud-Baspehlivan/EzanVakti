import Foundation

/// Kayıt dosyasındaki gün anahtarı — aynı zamanda saat ile telefon arasındaki
/// tek ortak dil.
///
/// Anahtarı **işareti koyan cihaz** üretiyor. Telefonun gelen işareti kendi
/// takvimiyle yeniden yorumlaması, iki cihaz farklı saat dilimindeyken ya da
/// gece yarısının iki yakasındayken işareti yanlış güne yazardı: bileğinde
/// 23:55'te "yatsıyı kıldım" diyen biri kaydı ertesi güne düşmüş bulurdu.
enum PrayerDay {
    static func key(for day: Date, in calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// Saatte konan tek bir işaret.
///
/// `markedAt` süsleme değil, çakışmayı çözen alan: saat çevrimdışıyken konan
/// işaret saatler sonra telefona ulaşabiliyor, o arada aynı vakit telefondan da
/// değiştirilmiş olabilir. Sırayı geliş anı belirlerse eski işaret yeninin
/// üstüne yazıyor; bu alan sayesinde kural "sonra işaretlenen kazanır" oluyor.
struct PrayerMark: Codable, Equatable, Sendable {
    let dayKey: String
    let prayer: Prayer
    let status: PrayerStatus
    let markedAt: Date
}

/// Saatten telefona giden paket. Tek işaret için bile zarf kullanılıyor ki
/// ileride toplu gönderim biçimi değiştirmesin.
struct PrayerMarkBatch: Codable, Equatable, Sendable {
    var marks: [PrayerMark]
}

/// Telefondan saate giden özet: son birkaç günün işaretleri.
///
/// Tüm kayıt değil son günler gönderiliyor — saatte gösterilen tek gün bugün,
/// yıllarca birikmiş kaydı bileğe taşımanın karşılığı yok.
struct PrayerLogDigest: Codable, Equatable, Sendable {
    var days: [String: [Prayer: PrayerStatus]]
    /// Özetin üretildiği an. Saat, bu andan **önce** işaretlediklerini bekleyen
    /// kuyruğundan düşürüyor: telefon o işareti ya uygulamış ya da daha yeni
    /// bir kararla geçersiz kılmış oluyor.
    var generatedAt: Date
}

/// WatchConnectivity sözlükleri yalnız plist türü taşıyor; `Codable` yükümüzü
/// tek bir `Data` alanına sarıp geçiriyoruz.
///
/// Anahtarda sürüm var: eski sürüm bir uygulamanın anlamadığı yükü sessizce
/// yanlış çözmesindense hiç görmemesi daha iyi.
///
/// Zarf **yalnız `Data` taşıyor**, çözmüyor. Ayrım kasıtlı: sözlük arka plan
/// kuyruğundan geliyor ama kayıt da ekran durumu da ana aktöre bağlı. Sözlük
/// taşınabilir bir tür değil, `Data` öyle — aktör sınırı tam burada geçiliyor,
/// çözme işi karşı tarafta yapılıyor.
///
/// `nonisolated`: hedeflerde varsayılan izolasyon `MainActor` ve bu tür
/// temsilci geri çağrılarının içinden, yani ana aktör dışından kullanılıyor.
nonisolated enum PrayerSyncEnvelope {
    static let marksKey = "ezan.marks.v1"
    static let digestKey = "ezan.digest.v1"

    static func wrap(_ data: Data, as key: String) -> [String: Any] { [key: data] }

    static func payload(from dictionary: [String: Any], as key: String) -> Data? {
        dictionary[key] as? Data
    }
}
