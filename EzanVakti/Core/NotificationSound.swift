import Foundation
import UserNotifications

struct NotificationSound: Identifiable, Hashable {
    let id: String
    let title: String
    /// nil ise iOS'un varsayılan bildirim sesi kullanılır.
    let fileName: String?

    static let system = NotificationSound(id: "system", title: "Sistem sesi", fileName: nil)

    /// Ses dosyası uygulama paketinde gerçekten var mı.
    var isBundled: Bool {
        guard let fileName else { return true }
        return Bundle.main.url(forResource: fileName, withExtension: nil) != nil
    }

    var unSound: UNNotificationSound {
        guard let fileName, isBundled else { return .default }
        return UNNotificationSound(named: UNNotificationSoundName(fileName))
    }
}

/// Beklenen ses dosyalarının kataloğu.
///
/// iOS, adı verilen ses dosyası pakette yoksa **hata vermeden** varsayılan sese
/// düşüyor — yani yanlış dosya adı sessizce yutuluyor. Bu yüzden katalog çalışma
/// zamanında süzülüyor ve ayarlarda yalnızca gerçekten paketlenmiş sesler listeleniyor.
///
/// Dosya biçimi zorunlulukları: Linear PCM / IMA4 / µLaw / aLaw, `.caf` `.aiff` veya
/// `.wav` konteynerde. MP3 ve M4A çalışmaz. Süre 30 saniyeyi geçerse iOS yine
/// varsayılan sese düşer. Dosyalar `EzanVakti/` klasörünün köküne konmalı.
enum NotificationSoundCatalog {
    /// Şu an yalnız sistem sesi.
    ///
    /// Pakette dört ezan/tekbir kaydı vardı ve **gönderim öncesi çıkarıldı.**
    /// Hepsi Wikimedia Commons'tan "own work" beyanıyla CC0/PD-self olarak
    /// alınmıştı; o beyan yükleyenin kendi ifadesi ve bağımsız doğrulanamıyor.
    /// Yayınlanmış bir uygulamada doğrulanamayan telif, sonradan kaldırılma
    /// riski demek — kaynağı teyit edilmiş ya da kendi kaydedilmiş bir ses
    /// bulunana kadar bekliyor.
    ///
    /// Geri eklemek: `Tools/make-sound.sh` ile dönüştür, `EzanVakti/` köküne
    /// koy, buraya bir satır ekle. Katalog zaten çalışma zamanında süzülüyor,
    /// başka hiçbir yere dokunmak gerekmiyor.
    static let all: [NotificationSound] = [.system]

    static var available: [NotificationSound] { all.filter(\.isBundled) }

    static func sound(id: String) -> NotificationSound {
        all.first { $0.id == id } ?? .system
    }
}
