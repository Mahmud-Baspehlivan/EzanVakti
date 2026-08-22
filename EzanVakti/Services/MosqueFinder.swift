import CoreLocation
import Foundation

enum MosqueSearchError: LocalizedError {
    case rateLimited
    case serverBusy
    case network

    var errorDescription: String? {
        switch self {
        case .rateLimited: return "Harita servisi şu an yoğun. Birkaç dakika sonra tekrar dene."
        case .serverBusy:  return "Harita servisi yanıt vermedi. Biraz sonra tekrar dene."
        case .network:     return "Camiler yüklenemedi. İnternet bağlantını kontrol et."
        }
    }
}

/// Yakındaki camileri OpenStreetMap'ten (Overpass API) bulur.
///
/// Önce Apple'ın `MKLocalSearch`'ü kullanılıyordu; ölçüm bunun bu iş için
/// elverişsiz olduğunu gösterdi: istek başına en fazla 25 sonuç döndürüyor ve
/// bunları yakınlığa değil ünlülüğe göre sıralıyor. Eyüpsultan'da 1 km yarıçapta
/// dönen 25 sonucun yalnızca 2'si gerçekten 1 km içindeydi; gerisi kilometrelerce
/// ötedeki meşhur camilerdi. Aynı noktada OSM 34 cami veriyor.
///
/// OSM'de ibadet yerleri `amenity=place_of_worship` + `religion=muslim` olarak
/// etiketli; isimden tahmin yürütmeye gerek kalmıyor, "Cami Sokak Kuaför"
/// türünden yanlış eşleşmeler de kendiliğinden ortadan kalkıyor.
enum MosqueFinder {
    /// Overpass topluluk sunucuları düzenli olarak 502/504 döndürüyor; ölçümde
    /// üçü de en az bir kez düştü. Sırayla deneniyor.
    private static let endpoints = [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter",
        "https://overpass.private.coffee/api/interpreter",
    ].compactMap(URL.init(string:))

    /// OSM'de tekke, medrese ve türbeler de `place_of_worship` etiketli ve
    /// etiketleri gerçek camilerden ayırt edilemiyor (aynı `building=mosque`,
    /// `denomination=sunni`). Ayırt eden tek şey ad. Ölçüldü: Eyüpsultan'da
    /// 34 kaydın 32'si adında cami/mescit geçiriyor, elenen ikisi
    /// "Sokullu Mehmet Paşa Medresesi" ve "Şeyhülislâm Mustafa Efendi Tekkesi".
    private static let nameStems = ["cami", "mescit", "mescid", "mosque", "masjid"]

    static func search(
        near coordinate: Coordinate,
        radius: CLLocationDistance
    ) async throws -> [Mosque] {
        if let cached = MosqueCache.load(near: coordinate, radius: radius) {
            return cached
        }
        let elements = try await fetch(near: coordinate, radius: radius)
        let result = mosques(from: elements, near: coordinate)
        MosqueCache.save(result, near: coordinate, radius: radius)
        return result
    }

    // MARK: - Ağ

    private static func fetch(
        near coordinate: Coordinate,
        radius: CLLocationDistance
    ) async throws -> [OverpassResponse.Element] {
        // `around:` yarıçap süzmesini sunucuda yapıyor; `nwr` düğüm, alan ve
        // ilişkiyi tek ifadede topluyor.
        let query = """
        [out:json][timeout:25];
        nwr["amenity"="place_of_worship"]["religion"="muslim"]\
        (around:\(Int(radius)),\(coordinate.latitude),\(coordinate.longitude));
        out center tags;
        """

        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let body = Data("data=\(query.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")".utf8)

        var lastError: MosqueSearchError = .network
        for endpoint in endpoints {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 20
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            // Overpass kullanım kuralları isteği tanımlamayı istiyor.
            request.setValue("EzanVakti/1.0", forHTTPHeaderField: "User-Agent")
            request.httpBody = body

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    // 429 kotayı, 5xx sunucu yoğunluğunu gösteriyor; ikisi de
                    // "internet yok" değil. Sıradaki sunucuyu deniyoruz.
                    lastError = http.statusCode == 429 ? .rateLimited : .serverBusy
                    continue
                }
                return try JSONDecoder().decode(OverpassResponse.self, from: data).elements
            } catch is DecodingError {
                lastError = .serverBusy
            } catch {
                lastError = .network
            }
        }
        throw lastError
    }

    // MARK: - Dönüştürme

    private static func mosques(
        from elements: [OverpassResponse.Element],
        near origin: Coordinate
    ) -> [Mosque] {
        elements
            .compactMap { element -> Mosque? in
                guard let coordinate = element.coordinate,
                      let tags = element.tags,
                      let name = tags["name"] ?? tags["name:tr"],
                      isMosqueName(name)
                else { return nil }

                return Mosque(
                    id: "\(element.type)/\(element.id)",
                    name: name,
                    address: address(from: tags),
                    coordinate: coordinate,
                    distance: origin.distance(to: coordinate),
                    bearing: origin.bearing(to: coordinate)
                )
            }
            .sorted { $0.distance < $1.distance }
    }

    /// Yerelden bağımsız katlama: `localizedStandardContains` Türkçe'de
    /// "FATİH CAMİİ" ile "cami"yi eşleştiremiyor, `locale: tr_TR` de çözmüyor.
    private static func isMosqueName(_ name: String) -> Bool {
        let folded = name.folding(options: [.caseInsensitive, .diacriticInsensitive],
                                  locale: nil)
        return nameStems.contains { folded.contains($0) }
    }

    /// OSM'de adres etiketleri seyrek; çoğu cami yalnızca adıyla kayıtlı.
    /// Ne bulunursa o gösteriliyor, hiçbiri yoksa satır boş kalıyor.
    private static func address(from tags: [String: String]) -> String {
        let street = [tags["addr:street"], tags["addr:housenumber"]]
            .compactMap { $0 }
            .joined(separator: " ")
        return [
            street.isEmpty ? nil : street,
            tags["addr:neighbourhood"],
            tags["addr:district"] ?? tags["addr:city"],
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }
}

private struct OverpassResponse: Decodable {
    struct Element: Decodable {
        struct Center: Decodable {
            let lat: Double
            let lon: Double
        }

        let type: String
        let id: Int
        let lat: Double?
        let lon: Double?
        /// Alan ve ilişki tipindeki kayıtlar için `out center` merkez noktası veriyor.
        let center: Center?
        let tags: [String: String]?

        var coordinate: Coordinate? {
            if let lat, let lon { return Coordinate(latitude: lat, longitude: lon) }
            if let center { return Coordinate(latitude: center.lat, longitude: center.lon) }
            return nil
        }
    }

    let elements: [Element]
}
