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

    init(enabled: Set<Prayer>, minutesBefore: Int, soundID: String) {
        self.enabled = enabled
        self.minutesBefore = minutesBefore
        self.soundID = soundID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decode(Set<Prayer>.self, forKey: .enabled)
        minutesBefore = try container.decode(Int.self, forKey: .minutesBefore)
        soundID = try container.decodeIfPresent(String.self, forKey: .soundID)
            ?? NotificationSound.system.id
    }

    static let `default` = NotificationPreferences(
        enabled: Set(Prayer.allCases.filter(\.isPrayer)),
        minutesBefore: 0,
        soundID: NotificationSound.system.id
    )
}

@Observable
final class NotificationPreferencesStore {
    private static let key = "notificationPreferences"

    var preferences: NotificationPreferences {
        didSet { persist() }
    }

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
