import Foundation

enum PrayerStatus: String, Codable, CaseIterable, Identifiable {
    case unmarked
    case performed
    case congregation
    case missed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unmarked:     return "—"
        case .performed:    return "Kıldım"
        case .congregation: return "Cemaatle"
        case .missed:       return "Kılmadım"
        }
    }

    var symbolName: String {
        switch self {
        case .unmarked:     return "circle.dashed"
        case .performed:    return "checkmark.circle.fill"
        case .congregation: return "person.3.fill"
        case .missed:       return "xmark.circle.fill"
        }
    }

    /// Gün "tamamlandı" sayılırken cemaat de kılınmış kabul ediliyor.
    var countsAsPerformed: Bool { self == .performed || self == .congregation }

    /// Kullanıcı dokundukça sırayla geçtiği düzen.
    var next: PrayerStatus {
        switch self {
        case .unmarked:     return .performed
        case .performed:    return .congregation
        case .congregation: return .missed
        case .missed:       return .unmarked
        }
    }
}

/// Kaza borcu üç bileşenden türetiliyor; tek bir sayaç tutup elle değiştirmek
/// çift sayma hatasına açık olurdu.
struct QadaLedger: Codable, Equatable {
    /// Kullanıcının uygulamayı kullanmaya başlamadan önceki birikmiş borcu.
    var opening: [Prayer: Int] = [:]
    /// Kaza olarak kılınıp düşülenler.
    var paid: [Prayer: Int] = [:]
}

struct PrayerLogSnapshot: Codable, Equatable {
    /// Gün anahtarı "yyyy-MM-dd".
    var days: [String: [Prayer: PrayerStatus]] = [:]
    var qada = QadaLedger()
}
