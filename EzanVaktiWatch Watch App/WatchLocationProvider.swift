import CoreLocation
import MapKit
import Observation
import WidgetKit

/// Saatin kendi konum sağlayıcısı.
///
/// Telefondaki `LocationProvider` yeniden kullanılmadı: o pusula yönü, elle
/// konum seçimi ve App Group paylaşımı taşıyor; saatte hiçbiri gerekmiyor ve
/// pusula API'lerinin watchOS'taki durumu ayrı bir belirsizlik. Burada tek iş
/// var — bir kez konumu çöz.
///
/// Çözülen konumu paylaşılan depoya da burası yazıyor: sahip tek bir yer olsun.
/// Yazma sorumluluğu ekrana bırakılırsa komplikasyon konumu ancak uygulama
/// açıldığında öğrenir; telefon tarafında da konumun sahibi sağlayıcı.
@Observable
final class WatchLocationProvider: NSObject, CLLocationManagerDelegate {
    private(set) var coordinate: Coordinate?
    private(set) var name = "İstanbul"
    private(set) var isDenied = false
    /// Son konum hatası. Varsayılanla devam etmek doğru ama sessiz kalmak değil:
    /// hata burada duruyor ki neden İstanbul'a düşüldüğü sorulabilsin.
    private(set) var lastErrorDescription: String?

    private let manager = CLLocationManager()

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
        // Ret açıkça yazılı: `default` altında toplanınca hangi durumların
        // oraya düştüğü okunmuyordu. Bilinmeyen bir durumu reddedilmiş saymak
        // güvenli taraf — varsayılana düşüp bunu ekranda söylüyoruz.
        case .denied, .restricted: isDenied = true
        @unknown default: isDenied = true
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isDenied = false
            manager.requestLocation()
        case .denied, .restricted:
            isDenied = true
        // Henüz sorulmamış olmak reddedilmiş olmakla aynı şey değil: izin
        // diyaloğu ekrandayken bayrağı kaldırmak, kullanıcı daha cevap vermeden
        // "konum kapalı" uyarısını yakıyor.
        case .notDetermined:
            isDenied = false
        @unknown default:
            isDenied = true
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastErrorDescription = nil
        coordinate = Coordinate(latitude: location.coordinate.latitude,
                                longitude: location.coordinate.longitude)
        Task { await resolveName(for: location) }
    }

    /// Konumun adını çözüp paylaşılan depoya yazar.
    ///
    /// `CLGeocoder` watchOS 26'da kullanımdan kalktı, yerine MapKit'in isteği
    /// geçti. Kazancı sadece uyarıyı susturmak değil: istek `async` olduğu için
    /// geri çağrı ve `[weak self]` dansı gerekmiyor. (Telefon tarafı iOS 17'yi
    /// desteklediği için orada hâlâ `CLGeocoder` duruyor — bu API iOS 26+.)
    ///
    /// Depoya yazma ada bağlanmadı ama adı bekliyor: koordinat çözülür çözülmez
    /// yazsaydık, saniyeler sonra gelen adla ikinci kez yazıp komplikasyonu iki
    /// kez yeniletiyorduk.
    @MainActor
    private func resolveName(for location: CLLocation) async {
        // MapKit ilçe/il ayrımı vermiyor, tek bir şehir adı veriyor. Diyanet
        // takvimi ilçe bazlı olsa da vakit farkı komşu ilçeler arasında saniyeler
        // mertebesinde; başlıktaki ad için bu ayrım kayba değmiyor.
        if let request = MKReverseGeocodingRequest(location: location),
           let items = try? await request.mapItems,
           let city = items.first?.addressRepresentations?.cityName {
            name = city
        }

        // Ad çözülemese de koordinat paylaşılıyor: komplikasyon vakitleri
        // koordinattan hesaplıyor, ad yalnızca başlıkta duruyor.
        guard let coordinate else { return }
        // Yenileme çağrısı burada: bu olmadan widget konum değişikliğini bir
        // sonraki zaman çizelgesi yenilemesine kadar görmez, saatlerce eski
        // şehri gösterebilir. `save` değişmediyse false döner, bütçe harcanmaz.
        if SharedLocationStore.save(coordinate: coordinate, name: name) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Varsayılanla devam ediliyor, vakitler yine gösteriliyor; ama hangi
        // hatanın buna yol açtığı kayboluyordu. Ekran zaten "varsayılan konum"
        // rozetini gösteriyor, sebebi burada duruyor.
        lastErrorDescription = error.localizedDescription
    }
}
