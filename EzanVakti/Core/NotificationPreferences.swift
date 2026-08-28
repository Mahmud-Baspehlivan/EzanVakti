import Foundation
import Observation

struct NotificationPreferences: Codable, Equatable {
    // soundID sonradan eklendi; eski kayıtlarda alan yok, o yüzden decode edilirken
    // varsayılana düşmesi gerekiyor (aşağıdaki init(from:)).
    /// Bildirim istenen vakitler. Güneş bir namaz vakti olmadığı için varsayılanda yok.
    var enabled: Set<Prayer>
    /// Vaktin kaç dakika öncesinde haber verilsin (0 = vaktin tam girişinde).
    var minutesBefore: Int
    /// `NotificationSoundCatalog` içindeki ses kimliği.
    var soundID: String
    /// Kilit ekranı ve Dinamik Ada geri sayımı.
    var liveActivityEnabled: Bool
    /// Geri sayım vaktin kaç dakika öncesinden görünsün.
    ///
    /// Eşik olmadan gün boyu bir sayaç asılı kalıyor. Ölçüldü: vakitler arası
    /// sürenin yarısı 3 saatten uzun ve Yatsı–İmsak kışın 11.5 saate çıkıyor —
    /// hem 6 saatlik bir geri sayım kimseye bir şey söylemiyor hem de Live
    /// Activity'nin 8 saatlik ömür sınırı aşılıyor.
    var liveActivityLeadMinutes: Int

    init(enabled: Set<Prayer>, minutesBefore: Int, soundID: String,
         liveActivityEnabled: Bool = true, liveActivityLeadMinutes: Int = 120) {
        self.enabled = enabled
        self.minutesBefore = minutesBefore
        self.soundID = soundID
        self.liveActivityEnabled = liveActivityEnabled
        self.liveActivityLeadMinutes = liveActivityLeadMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decode(Set<Prayer>.self, forKey: .enabled)
        minutesBefore = try container.decode(Int.self, forKey: .minutesBefore)
        soundID = try container.decodeIfPresent(String.self, forKey: .soundID)
            ?? NotificationSound.system.id
        liveActivityEnabled = try container
            .decodeIfPresent(Bool.self, forKey: .liveActivityEnabled) ?? true
        liveActivityLeadMinutes = try container
            .decodeIfPresent(Int.self, forKey: .liveActivityLeadMinutes) ?? 120
    }

    static let `default` = NotificationPreferences(
        enabled: Set(Prayer.allCases.filter(\.isPrayer)),
        minutesBefore: 0,
        soundID: NotificationSound.system.id,
        liveActivityEnabled: true,
        liveActivityLeadMinutes: 120
    )
}

@Observable
final class NotificationPreferencesStore {
    private static let key = "notificationPreferences"

    var preferences: NotificationPreferences {
        didSet { persist() }
    }

    // Kardeşlerinin (LocationPreferenceStore, MapAppPreferenceStore) aksine App Group
    // suite'i değil `.standard`: bildirim tercihlerini bugün yalnızca uygulama okuyor.
    // Uzantılardan biri de bakmaya başlarsa (örn. widget "bildirim açık" rozeti
    // gösterirse) App Group suite'ine taşınması gerekir.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            preferences = decoded
        } else {
            preferences = .default
        }
    }

    private let defaults: UserDefaults

    private func persist() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
