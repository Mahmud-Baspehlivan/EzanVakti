import CoreLocation
import Observation

/// Saatin kendi konum sağlayıcısı.
///
/// Telefondaki `LocationProvider` yeniden kullanılmadı: o pusula yönü, elle
/// konum seçimi ve App Group paylaşımı taşıyor; saatte hiçbiri gerekmiyor ve
/// pusula API'lerinin watchOS'taki durumu ayrı bir belirsizlik. Burada tek iş
/// var — bir kez konumu çöz.
@Observable
final class WatchLocationProvider: NSObject, CLLocationManagerDelegate {
    private(set) var coordinate: Coordinate?
    private(set) var name = "İstanbul"
    private(set) var isDenied = false

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        // Namaz vakti için kilometre hassasiyeti yeterli; saatin pilini yormuyoruz.
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        default: isDenied = true
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isDenied = false
            manager.requestLocation()
        case .denied, .restricted:
            isDenied = true
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let resolved = Coordinate(latitude: location.coordinate.latitude,
                                  longitude: location.coordinate.longitude)
        coordinate = resolved

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self, let place = placemarks?.first else { return }
            // İlçe varsa onu tercih ediyoruz; Diyanet takvimi de ilçe bazlı.
            self.name = place.subAdministrativeArea ?? place.administrativeArea ?? self.name
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Konum çözülemezse varsayılanla devam ediliyor; vakitler yine gösteriliyor.
    }
}
