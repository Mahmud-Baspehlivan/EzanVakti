import CoreLocation
import Observation
import WidgetKit

/// Konum durumu bilerek açıkça modellendi: izin yoksa sessizce varsayılana
/// düşüp doğru yeri gösteriyormuş gibi yapmıyoruz, ekran bunu kullanıcıya söylüyor.
///
/// `Equatable`: ekranlar durumu `onChange` ile izliyor. Bu olmadan her ekran
/// karşılaştırmak için kendi kimlik dizesini uyduruyordu; üç ayrı gövde, üç ayrı
/// "değişti mi" tanımı demekti.
enum LocationState: Equatable {
    case idle
    case requesting
    case resolved(Coordinate, name: String)
    case denied
    case failed(String)
}

/// Cihazın baktığı yön. Doğruluk negatifse pusula okuması geçersiz —
/// manyetik parazit veya kalibrasyon eksikliği demek.
struct DeviceHeading {
    let degrees: Double
    let accuracy: Double

    var isValid: Bool { accuracy >= 0 }
    var needsCalibration: Bool { !isValid || accuracy > 15 }
}

@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private(set) var state: LocationState = .idle
    private(set) var heading: DeviceHeading?
    private(set) var mode: LocationMode = LocationPreferenceStore.mode

    var isHeadingAvailable: Bool { CLLocationManager.headingAvailable() }

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        // Namaz vakti için kilometre hassasiyeti yeterli; GPS'i boşa yormuyoruz.
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func start() {
        // Elle konum seçilmişse GPS'e hiç dokunmuyoruz.
        //
        // `publish` ile: uygulama yeniden kurulduğunda veya App Group verisi
        // temizlendiğinde widget elle seçilen konumu ancak kullanıcı yeniden
        // seçerse görüyordu. Aynı konum tekrar yazıldığında `save` zaten
        // yenileme tetiklemiyor, yani bedeli yok.
        if case .manual(let latitude, let longitude, let name) = mode {
            publish(Coordinate(latitude: latitude, longitude: longitude), name: name)
            return
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            state = .requesting
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            state = .denied
        case .authorizedWhenInUse, .authorizedAlways:
            state = .requesting
            manager.requestLocation()
        @unknown default:
            state = .denied
        }
    }

    /// Pusula sadece ona ihtiyacı olan ekran görünürken açılıyor; sürekli açık
    /// tutmak gereksiz pil tüketiyor.
    ///
    /// Sayaç şart: kıble ve camiler sekmeleri arasında geçerken SwiftUI yeni
    /// ekranın `onAppear`'ını eskisinin `onDisappear`'ından önce çağırabiliyor.
    @ObservationIgnored private var headingConsumers = 0

    func startHeading() {
        guard CLLocationManager.headingAvailable() else { return }
        headingConsumers += 1
        manager.startUpdatingHeading()
    }

    func stopHeading() {
        headingConsumers = max(0, headingConsumers - 1)
        guard headingConsumers == 0 else { return }
        manager.stopUpdatingHeading()
        heading = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // trueHeading konum izni yoksa -1 döner; o durumda manyetik kuzeye düşüyoruz.
        let degrees = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        heading = DeviceHeading(degrees: degrees, accuracy: newHeading.headingAccuracy)
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        true
    }

    /// Ekran durumu ile widget'ın okuduğu paylaşılan depoyu birlikte güncelliyor.
    /// Kaydetme sorumluluğu bir sekmenin görünüm modeline dağılırsa konum widget'a
    /// ancak o sekme açıldığında ulaşıyor; tek sahip burası.
    private func publish(_ coordinate: Coordinate, name: String) {
        state = .resolved(coordinate, name: name)
        // Yenileme çağrısı burada: bu olmadan widget konum değişikliğini bir
        // sonraki zaman çizelgesi yenilemesine kadar görmez, saatlerce eski
        // şehri gösterebilir. `save` değişmediyse false döner, bütçe harcanmaz.
        if SharedLocationStore.save(coordinate: coordinate, name: name) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Konum kaynağını değiştirir ve tercihi kalıcılaştırır.
    func setMode(_ newMode: LocationMode) {
        mode = newMode
        LocationPreferenceStore.mode = newMode

        switch newMode {
        case .manual(let latitude, let longitude, let name):
            geocoder.cancelGeocode()
            publish(Coordinate(latitude: latitude, longitude: longitude), name: name)
        case .automatic:
            state = .idle
            start()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Elle seçim varken yetki değişimi konumu ele geçirmemeli.
        guard !mode.isManual else { return }

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            state = .requesting
            manager.requestLocation()
        case .denied, .restricted:
            state = .denied
        case .notDetermined:
            state = .idle
        @unknown default:
            state = .denied
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !mode.isManual, let location = locations.last else { return }
        let coordinate = Coordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        // Ekran beklemesin diye ara ad hemen görünüyor, ama paylaşılan depoya
        // yazmıyoruz: ters kodlama saniyeler içinde gerçek adı getirecek ve iki
        // farklı adla iki kez yazmak iki widget yenilemesi harcıyordu.
        state = .resolved(coordinate, name: "Konum bulundu")

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            // `mode` yeniden denetleniyor: bu kapanış saniyeler sonra dönüyor ve
            // arada kullanıcı elle konum seçmiş olabilir. `cancelGeocode()` iptal
            // edilen isteği de tamamlatıyor (kCLErrorGeocodeCanceled), yani bu dal
            // denetimsiz bırakılırsa elle seçilen şehri GPS koordinatıyla eziyor —
            // hem ekranda hem App Group'ta.
            guard let self, !self.mode.isManual else { return }
            let place = placemarks?.first
            // İlçe varsa onu tercih ediyoruz; Diyanet takvimi de ilçe bazlı.
            let name = [place?.subAdministrativeArea, place?.administrativeArea]
                .compactMap { $0 }
                .first ?? "Bilinmeyen konum"
            self.publish(coordinate, name: name)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard !mode.isManual else { return }
        state = .failed(error.localizedDescription)
    }
}
