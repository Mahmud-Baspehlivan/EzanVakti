import CoreLocation
import Foundation

/// Türkiye cami verisi uygulamayla birlikte geliyor; bu kapsamda ağ hiç
/// kullanılmıyor.
///
/// Neden paketlendi: Overpass topluluk sunucusu ve kullanım kuralları
/// yayınlanmış bir uygulamadan gelen düzenli trafiği kapsamıyor. Ayrıca ölçümde
/// yanıt süresi 1.5–14 sn arasında değişiyor, arada 504 dönüyordu. Paketlenmiş
/// veriyle sonuç anında geliyor ve çevrimdışı da çalışıyor.
///
/// Veri OpenStreetMap'ten tek seferlik çıkarım (`Tools/mosque-extract`), ODbL.
/// Bedeli: veri uygulama güncellemesiyle tazeleniyor.
enum BundledMosqueSource {
    /// Kabaca Türkiye sınırları. Bu kutunun dışındaki konumlar için paketlenmiş
    /// veri yok; çağıran taraf Overpass'a düşüyor.
    static let coverage = (minLatitude: 35.5, maxLatitude: 42.6,
                           minLongitude: 25.0, maxLongitude: 45.5)

    static func covers(_ coordinate: Coordinate) -> Bool {
        coordinate.latitude >= coverage.minLatitude && coordinate.latitude <= coverage.maxLatitude
            && coordinate.longitude >= coverage.minLongitude && coordinate.longitude <= coverage.maxLongitude
    }

    struct Record {
        let latitude: Double
        let longitude: Double
        let name: String
    }

    /// 45 bin kayıt bellekte ~4 MB tutuyor ve tarama milisaniye altı sürüyor;
    /// mekânsal indeks kurmak bu ölçekte gereksiz karmaşıklık olurdu.
    private static let records: [Record] = load(from: bundledURL)

    /// Testten dosya yolu verilebilsin diye ayrı; uygulamada paketten okunuyor.
    static var bundledURL: URL? {
        Bundle.main.url(forResource: "tr-mosques", withExtension: "txt")
    }

    static func load(from url: URL?) -> [Record] {
        guard let url, let text = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }

        var result: [Record] = []
        result.reserveCapacity(50_000)
        // Satır biçimi: enlem;boylam;ad — JSON'un ayrıştırma yükünü taşımıyor.
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let parts = line.split(separator: ";", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count == 3,
                  let lat = Double(parts[0]), let lon = Double(parts[1]),
                  !parts[2].isEmpty
            else { continue }
            result.append(Record(latitude: lat, longitude: lon, name: String(parts[2])))
        }
        return result
    }

    static func search(near origin: Coordinate, radius: CLLocationDistance) -> [Mosque] {
        search(in: records, near: origin, radius: radius)
    }

    static func search(in records: [Record], near origin: Coordinate,
                       radius: CLLocationDistance) -> [Mosque] {
        // Enlem/boylam kutusuyla ön eleme: her kayıt için haversine hesaplamak
        // yerine önce kaba bir aralık süzgeci uyguluyoruz.
        let latitudeSpan = radius / 111_000
        let longitudeSpan = radius / (111_000 * max(0.2, Deg.cos(origin.latitude)))

        return records
            .lazy
            .filter { abs($0.latitude - origin.latitude) <= latitudeSpan
                   && abs($0.longitude - origin.longitude) <= longitudeSpan }
            .compactMap { record -> Mosque? in
                let coordinate = Coordinate(latitude: record.latitude, longitude: record.longitude)
                let distance = origin.distance(to: coordinate)
                guard distance <= radius else { return nil }
                return Mosque(
                    id: "\(record.latitude),\(record.longitude)",
                    name: record.name,
                    address: "",
                    coordinate: coordinate,
                    distance: distance,
                    bearing: origin.bearing(to: coordinate)
                )
            }
            .sorted { $0.distance < $1.distance }
    }
}
