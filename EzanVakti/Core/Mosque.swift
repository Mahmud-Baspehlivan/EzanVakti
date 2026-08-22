import Foundation

/// Uzaklık ve yön arama anında bir kez hesaplanıyor; kullanıcı yürürken
/// satırlar birbirinin yerine atlamasın.
struct Mosque: Identifiable, Equatable {
    let id: String
    let name: String
    /// Apple Haritalar her cami için adres döndürmüyor; boş olabilir.
    let address: String
    let coordinate: Coordinate
    /// Metre.
    let distance: Double
    /// Kuzeyden saat yönünde derece.
    let bearing: Double

    /// Metre 10'a yuvarlanıyor: "437 m" GPS'in vaat etmediği bir kesinlik satıyor.
    var distanceText: String {
        if distance < 1_000 {
            return "\(Int((distance / 10).rounded()) * 10) m"
        }

        let km = distance / 1_000
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.maximumFractionDigits = distance < 10_000 ? 1 : 0
        return (formatter.string(from: NSNumber(value: km)) ?? "\(Int(km))") + " km"
    }

    static func == (lhs: Mosque, rhs: Mosque) -> Bool { lhs.id == rhs.id }
}

/// Yol tarifinin hangi ulaşım biçiminde açılacağı.
enum TravelMode {
    case walking
    case driving
}

enum MosqueSearchRadius: Double, CaseIterable, Identifiable {
    case walking = 1_000
    case district = 5_000
    case wide = 25_000

    var id: Double { rawValue }

    var title: String {
        switch self {
        case .walking:  return "1 km"
        case .district: return "5 km"
        case .wide:     return "25 km"
        }
    }

    /// 1 km yürünür; 5 ve 25 km'de yaya tarifi anlamsız uzunlukta çıkıyor.
    var travelMode: TravelMode {
        self == .walking ? .walking : .driving
    }
}
