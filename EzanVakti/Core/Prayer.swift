import Foundation

enum Prayer: String, CaseIterable, Identifiable, Codable {
    case imsak, gunes, ogle, ikindi, aksam, yatsi

    var id: String { rawValue }

    var title: String {
        switch self {
        case .imsak:  return "İmsak"
        case .gunes:  return "Güneş"
        case .ogle:   return "Öğle"
        case .ikindi: return "İkindi"
        case .aksam:  return "Akşam"
        case .yatsi:  return "Yatsı"
        }
    }

    /// Güneş bir namaz vakti değil, sabah namazının çıkış anı.
    var isPrayer: Bool { self != .gunes }

    var symbolName: String {
        switch self {
        case .imsak:  return "moon.stars"
        case .gunes:  return "sunrise"
        case .ogle:   return "sun.max"
        case .ikindi: return "sun.min"
        case .aksam:  return "sunset"
        case .yatsi:  return "moon"
        }
    }
}

/// `[Prayer: X]` sözlükleri JSON'da nesne olarak kodlansın diye. Bu olmadan
/// Swift onları anahtar/değer dizisine çeviriyor; dosya okunaksız oluyor.
extension Prayer: CodingKeyRepresentable {}

struct Coordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double

    static let istanbul = Coordinate(latitude: 41.0082, longitude: 28.9784)
    static let kaaba = Coordinate(latitude: 21.4225, longitude: 39.8262)
}

/// Bir güne ait vakitler. `Prayer` ile indekslenebilir olması ekran tarafını
/// switch/case yığınından kurtarıyor.
struct DailyPrayerTimes {
    let day: Date
    private let times: [Prayer: Date]

    /// Gerçek güneş doğuşu/batışı — Diyanet'in temkin uyguladığı vakitlerden ayrı,
    /// kerahat penceresi hesabı için tutuluyor.
    let trueSunrise: Date
    let trueSunset: Date

    /// Eksik sözlükle kurulamıyor. Bu sayede aşağıdaki `subscript` zorlama
    /// açmayı güvenle yapabiliyor: geçersiz durum en baştan temsil edilemiyor,
    /// çağıran her yere opsiyonel yaymak gerekmiyor.
    init?(day: Date, times: [Prayer: Date], trueSunrise: Date, trueSunset: Date) {
        guard Prayer.allCases.allSatisfy({ times[$0] != nil }) else { return nil }
        self.day = day
        self.times = times
        self.trueSunrise = trueSunrise
        self.trueSunset = trueSunset
    }

    subscript(prayer: Prayer) -> Date { times[prayer]! }

    var ordered: [(prayer: Prayer, date: Date)] {
        Prayer.allCases.map { ($0, self[$0]) }
    }

    /// Şu ana göre sıradaki vakit. Yatsıdan sonra nil döner; çağıran taraf
    /// yarının imsakına geçmekle yükümlü.
    func next(after now: Date) -> (prayer: Prayer, date: Date)? {
        ordered.first { $0.date > now }
    }

    /// İçinde bulunulan vakit dilimi (imsaktan önce nil).
    func current(at now: Date) -> Prayer? {
        ordered.last { $0.date <= now }?.prayer
    }
}
