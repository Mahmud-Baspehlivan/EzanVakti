import Foundation

/// Arama sonuçlarını diske yazar.
///
/// Overpass topluluk sunucusu; ölçümde aynı sorgu 1.5 sn ile 14 sn arasında
/// değişti, arada 504 de döndü. Camiler yer değiştirmediği için sonucu saklamak
/// hem beklemeyi hem sunucuya yükü ortadan kaldırıyor.
enum MosqueCache {
    /// Camiler nadiren değişiyor; bu süre beklemeyle tazelik arasında makul bir yer.
    private static let lifetime: TimeInterval = 30 * 24 * 3600

    private struct Entry: Codable {
        struct Record: Codable {
            let id: String
            let name: String
            let address: String
            let coordinate: Coordinate
        }

        let savedAt: Date
        let records: [Record]
    }

    /// Anahtar ~100 m'ye yuvarlanıyor: birkaç adım atınca önbellek ıskalamasın.
    private static func key(_ coordinate: Coordinate, _ radius: Double) -> String {
        let lat = (coordinate.latitude * 1_000).rounded() / 1_000
        let lon = (coordinate.longitude * 1_000).rounded() / 1_000
        return "\(lat)_\(lon)_\(Int(radius))"
    }

    private static func url(for key: String) -> URL? {
        guard let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        return base
            .appendingPathComponent("MosqueCache", isDirectory: true)
            .appendingPathComponent("\(key).json")
    }

    /// Uzaklık ve yön önbellekten okunmuyor, çağıran konuma göre yeniden
    /// hesaplanıyor; aksi halde yuvarlanmış anahtarın hatası listeye sızardı.
    static func load(near coordinate: Coordinate, radius: Double) -> [Mosque]? {
        guard let url = url(for: key(coordinate, radius)),
              let data = try? Data(contentsOf: url),
              let entry = try? JSONDecoder().decode(Entry.self, from: data),
              Date().timeIntervalSince(entry.savedAt) < lifetime
        else { return nil }

        return entry.records
            .map { record in
                Mosque(id: record.id, name: record.name, address: record.address,
                       coordinate: record.coordinate,
                       distance: coordinate.distance(to: record.coordinate),
                       bearing: coordinate.bearing(to: record.coordinate))
            }
            .sorted { $0.distance < $1.distance }
    }

    static func save(_ mosques: [Mosque], near coordinate: Coordinate, radius: Double) {
        guard let url = url(for: key(coordinate, radius)) else { return }
        let entry = Entry(savedAt: Date(), records: mosques.map {
            Entry.Record(id: $0.id, name: $0.name, address: $0.address, coordinate: $0.coordinate)
        })
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
