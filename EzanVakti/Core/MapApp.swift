import Foundation

/// Yol tarifinin açılacağı harita uygulaması.
enum MapApp: String, CaseIterable, Identifiable {
    case apple, google, yandexMaps, yandexNavi

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple:      return "Apple Haritalar"
        case .google:     return "Google Maps"
        case .yandexMaps: return "Yandex Haritalar"
        case .yandexNavi: return "Yandex Navigasyon"
        }
    }

    /// `canOpenURL` bu şemayı ancak Info.plist'teki `LSApplicationQueriesSchemes`
    /// listesinde yer alıyorsa cevaplıyor. Apple Haritalar her cihazda var.
    var scheme: String? {
        switch self {
        case .apple:      return nil
        case .google:     return "comgooglemaps"
        case .yandexMaps: return "yandexmaps"
        case .yandexNavi: return "yandexnavi"
        }
    }

    /// Rota bağlantısı; her uygulamanın parametre adları farklı.
    /// Yandex Navigasyon araç navigasyonu olduğu için yaya kipi yok.
    func directionsURL(to coordinate: Coordinate, mode: TravelMode) -> URL? {
        let destination = "\(coordinate.latitude),\(coordinate.longitude)"
        switch self {
        case .apple:
            return URL(string: "maps://?daddr=\(destination)&dirflg=\(mode == .walking ? "w" : "d")")
        case .google:
            let google = mode == .walking ? "walking" : "driving"
            return URL(string: "comgooglemaps://?daddr=\(destination)&directionsmode=\(google)")
        case .yandexMaps:
            // rtext'in başındaki ~ "başlangıç mevcut konum"; rtt=pd yaya, rtt=auto araç.
            let rtt = mode == .walking ? "pd" : "auto"
            return URL(string: "yandexmaps://maps.yandex.com/?rtext=~\(destination)&rtt=\(rtt)")
        case .yandexNavi:
            return URL(string: "yandexnavi://build_route_on_map?lat_to=\(coordinate.latitude)&lon_to=\(coordinate.longitude)")
        }
    }
}

/// Tercih konum tercihiyle aynı yerde, App Group'ta duruyor.
enum MapAppPreferenceStore {
    private static let key = "preferredMapApp"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: SharedLocationStore.appGroupID) ?? .standard
    }

    static var app: MapApp {
        get { MapApp(rawValue: defaults.string(forKey: key) ?? "") ?? .apple }
        set { defaults.set(newValue.rawValue, forKey: key) }
    }
}
