import Foundation
import WidgetKit

/// Uygulama ile widget arasında paylaşılan son bilinen konum.
///
/// Widget kendi başına konum izni isteyemiyor; uygulama konumu çözdüğünde buraya
/// yazıyor, widget okuyor. App Group yapılandırılmamışsa `suite` nil döner —
/// bu durumda widget sessizce yanlış şehri göstermek yerine varsayılana düşüp
/// bunu ekranda belirtiyor.
enum SharedLocationStore {
    static let appGroupID = "group.com.mahmud.ezanvakti"

    private static let latitudeKey = "shared.latitude"
    private static let longitudeKey = "shared.longitude"
    private static let nameKey = "shared.locationName"

    private static var suite: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static var isAvailable: Bool { suite != nil }

    static func save(coordinate: Coordinate, name: String) {
        guard let suite else { return }

        // Aynı konum tekrar yazılırsa widget'ı boşuna yenilemeyelim; WidgetKit
        // yenileme bütçesi sınırlı.
        let isSame = suite.object(forKey: latitudeKey) != nil
            && abs(suite.double(forKey: latitudeKey) - coordinate.latitude) < 0.0001
            && abs(suite.double(forKey: longitudeKey) - coordinate.longitude) < 0.0001
            && suite.string(forKey: nameKey) == name

        suite.set(coordinate.latitude, forKey: latitudeKey)
        suite.set(coordinate.longitude, forKey: longitudeKey)
        suite.set(name, forKey: nameKey)

        // Bu çağrı olmadan widget konum değişikliğini bir sonraki zaman çizelgesi
        // yenilemesine kadar görmez — saatlerce eski şehri gösterebilir.
        guard !isSame else { return }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Kayıtlı konum yoksa nil — çağıran taraf varsayılana düşmeye kendi karar verir.
    static func load() -> (coordinate: Coordinate, name: String)? {
        guard let suite, suite.object(forKey: latitudeKey) != nil else { return nil }
        let coordinate = Coordinate(
            latitude: suite.double(forKey: latitudeKey),
            longitude: suite.double(forKey: longitudeKey)
        )
        return (coordinate, suite.string(forKey: nameKey) ?? "Bilinmeyen konum")
    }
}
