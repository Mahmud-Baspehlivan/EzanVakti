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
    static let all: [NotificationSound] = [
        .system,
        NotificationSound(id: "tekbir", title: "Tekbir (8 sn)", fileName: "tekbir.caf"),
        NotificationSound(id: "ezan-kisa", title: "Ezan (12 sn)", fileName: "ezan-kisa.caf"),
        NotificationSound(id: "ezan-orta", title: "Ezan (23 sn)", fileName: "ezan-orta.caf"),
        NotificationSound(id: "ezan-tam", title: "Ezan (29 sn)", fileName: "ezan-tam.caf"),
    ]

    static var available: [NotificationSound] { all.filter(\.isBundled) }

    static func sound(id: String) -> NotificationSound {
        all.first { $0.id == id } ?? .system
    }
}
