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
    /// geçti. Yenisi `async` olduğu için geri çağrı ve `[weak self]` dansı da
    /// gerekmiyor.
    ///
    /// Ama **koşulsuz kullanılamaz**: bu API watchOS 26+ ve tek başına bütün
    /// saat hedefini oraya çiviliyordu — en son güncellemeyi yüklememiş her
    /// saati dışarıda bırakan bir maliyet, üstelik yalnız başlıktaki şehir adı
    /// için. Altında `CLGeocoder`'a düşülüyor; telefon tarafı zaten onu
    /// kullanıyor (iOS 17'yi desteklediği için).
    ///
    /// Depoya yazma ada bağlanmadı ama adı bekliyor: koordinat çözülür çözülmez
    /// yazsaydık, saniyeler sonra gelen adla ikinci kez yazıp komplikasyonu iki
    /// kez yeniletiyorduk.
    @MainActor
    private func resolveName(for location: CLLocation) async {
        if let resolved = await Self.cityName(for: location) { name = resolved }

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

    /// Konumun şehir adı. İki API, aynı sonuç.
    ///
    /// MapKit ilçe/il ayrımı vermiyor, tek bir şehir adı veriyor; `CLGeocoder`
    /// veriyor ve orada telefonla aynı tercih uygulanıyor (ilçe varsa ilçe,
    /// Diyanet takvimi de ilçe bazlı). İki sürüm arasında adın bu kadar
    /// değişmesi kabul edilen bir fark: vakit farkı komşu ilçeler arasında
    /// saniyeler mertebesinde, ad yalnızca başlıkta duruyor.
    private static func cityName(for location: CLLocation) async -> String? {
        if #available(watchOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location),
                  let items = try? await request.mapItems else { return nil }
            return items.first?.addressRepresentations?.cityName
        }
        guard let places = try? await CLGeocoder().reverseGeocodeLocation(location) else { return nil }
        let place = places.first
        return [place?.subAdministrativeArea, place?.administrativeArea]
            .compactMap { $0 }
            .first
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Varsayılanla devam ediliyor, vakitler yine gösteriliyor; ama hangi
        // hatanın buna yol açtığı kayboluyordu. Ekran zaten "varsayılan konum"
        // rozetini gösteriyor, sebebi burada duruyor.
        lastErrorDescription = error.localizedDescription
    }
}
