import Foundation

/// Konumun nereden geleceği. Elle seçim yapılmışsa GPS hiç açılmıyor —
/// hem pil hem mahremiyet açısından doğrusu bu.
enum LocationMode: Codable, Equatable {
    case automatic
    case manual(latitude: Double, longitude: Double, name: String)

    var isManual: Bool {
        if case .manual = self { return true }
        return false
    }

    var manualName: String? {
        if case .manual(_, _, let name) = self { return name }
        return nil
    }
}

/// Tercih App Group'ta saklanıyor ki widget da aynı seçimi görsün.
/// App Group kurulu değilse uygulamanın kendi alanına düşüyor; o durumda
/// widget varsayılan konumla çalışmaya devam eder.
enum LocationPreferenceStore {
    private static let key = "locationMode"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: SharedLocationStore.appGroupID) ?? .standard
    }

    static var mode: LocationMode {
        get {
            guard let data = defaults.data(forKey: key),
                  let decoded = try? JSONDecoder().decode(LocationMode.self, from: data)
            else { return .automatic }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: key)
        }
    }
}
