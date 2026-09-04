import SwiftUI

extension PrayerStatus {
    var tint: Color {
        switch self {
        case .unmarked:     return Color.white.opacity(0.22)
        case .performed:    return Color(red: 0.30, green: 0.78, blue: 0.45)
        case .congregation: return Color(red: 0.35, green: 0.66, blue: 0.92)
        case .missed:       return Color(red: 0.90, green: 0.45, blue: 0.35)
        }
    }
}
