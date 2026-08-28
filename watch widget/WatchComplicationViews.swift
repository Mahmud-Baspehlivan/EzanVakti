import SwiftUI
import WidgetKit

/// Kadran komplikasyonları. Saf SwiftUI — `Tools/render` ile denetlenebiliyor.
///
/// Komplikasyonlar sistem tarafından tek renge tonlanıyor, o yüzden altın vurgu
/// kullanılmıyor. Geri sayım ve halka `timerInterval` alan sürümlerle kuruluyor:
/// zaman çizelgesi yalnızca vakit geçişlerinde girdi ürettiği için durağan bir
/// gösterge saatlerce donuk kalırdı.
///
/// Geri düşüş konumu (App Group boş ya da konum izni yok) yalnızca dikdörtgen
/// ve tek satır ailelerinde belirtiliyor. Tonlama yüzünden uyarı renkle
/// verilemiyor, geriye yer kaplayan bir simge kalıyor; daire ve köşede o yeri
/// vaktin simgesi tutuyor ve onu harcamak hangi vakte bakıldığını gizlerdi.
/// Yanlış şehrin vaktini sessizce göstermek kötü, ama bu iki dar ailede vaktin
/// kimliğini feda etmek daha kötü — uyarıyı geniş aileler ve uygulama veriyor.

/// `en_US_POSIX`: sabit "HH:mm" biçimi ancak yerelden bağımsız bir takvimle
/// güvenilir, aksi hâlde "24 Saat" anahtarını kapatan kullanıcıda sistem
/// biçimi AM/PM'e çeviriyor. Saat dilimi `.autoupdatingCurrent`, çünkü
/// biçimlendirici uzantı süreci boyunca yaşıyor ve dilim değişimini kaçırmamalı.
///
/// `@MainActor`: `DateFormatter` Sendable değil, dosya kapsamlı bir kopya Swift
/// 6 kipinde doğrudan hata. Bu hedefte varsayılan yalıtım zaten MainActor ve tek
/// çağrı yeri görünüm gövdeleri, yani ana aktör — yalıtımı açıkça yazmak sorunu
/// `nonisolated(unsafe)` gibi gizlemek yerine gerçekten çözüyor.
@MainActor
private let complicationFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .autoupdatingCurrent
    formatter.dateFormat = "HH:mm"
    return formatter
}()

@MainActor
private func hhmm(_ date: Date) -> String { complicationFormatter.string(from: date) }

/// Kadranda küçük daire: halka geçen oranı, ortada saat.
struct WatchCircularComplication: View {
    let entry: PrayerEntry

    var body: some View {
        if let upcoming = entry.upcoming, let previous = entry.previous {
            ZStack {
                ProgressView(timerInterval: previous...upcoming.date, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.circular)

                VStack(spacing: -1) {
                    Image(systemName: upcoming.prayer.symbolName)
                        .font(.system(size: 9))
                    Text(hhmm(upcoming.date))
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                }
            }
        } else {
            Image(systemName: "moon.stars")
        }
    }
}

/// Kadran köşesi: kalan süre kavisli kenarda, vakit simgesi içeride.
///
/// Kalan süre `widgetLabel` ile kenara yazılıyor, köşenin iç alanına değil:
/// orası dört-beş karakter alıyor ve geri sayım kış gecesi sekiz haneye kadar
/// çıkıyor ("10:41:34"). Kavisli kenarda yer var; hangi vakit olduğunu da
/// içerideki simge söylüyor.
///
/// Aralığın alt ucu `entry.previous` değil `entry.date`: geri sayım için yalnız
/// üst uç gerekli, `previous` ise isteğe bağlı ve gereksiz bir nil dalı açıyor.
struct WatchCornerComplication: View {
    let entry: PrayerEntry

    var body: some View {
        if let upcoming = entry.upcoming {
            Image(systemName: upcoming.prayer.symbolName)
                .font(.system(size: 16))
                .widgetLabel {
                    Text(timerInterval: entry.date...upcoming.date, countsDown: true)
                }
        } else {
            Image(systemName: "moon.stars")
        }
    }
}

/// Dikdörtgen: en çok bilgi sığan hâl.
struct WatchRectangularComplication: View {
    let entry: PrayerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let upcoming = entry.upcoming, let previous = entry.previous {
                HStack(spacing: 4) {
                    Image(systemName: upcoming.prayer.symbolName)
                        .font(.system(size: 10))
                    Text(upcoming.prayer.title)
                        .font(.system(size: 14, weight: .semibold))
                    Spacer(minLength: 0)
                    Text(hhmm(upcoming.date))
                        .font(.system(size: 14, weight: .semibold))
                        .monospacedDigit()
                }
                // Geri düşüş işareti geri sayım satırına iliştiriliyor, yeni bir
                // satıra değil: üç satır da dolu, dördüncüsü taşardı. Şehir adı
                // da yazılıyor, çünkü tek başına çizili simge "konum yok" diyor
                // ama hangi şehrin vaktine bakıldığını söylemiyor. Genişlik
                // öngörülebilir: geri düşüşte ad her zaman "İstanbul".
                HStack(spacing: 3) {
                    Text(timerInterval: previous...upcoming.date, countsDown: true)
                        .monospacedDigit()
                    if entry.isUsingFallbackLocation {
                        Spacer(minLength: 4)
                        Image(systemName: "location.slash")
                        Text(entry.locationName).lineLimit(1)
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                ProgressView(timerInterval: previous...upcoming.date, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.linear)
            } else {
                Text("Vakit hesaplanamadı").font(.system(size: 12))
            }
        }
    }
}

/// Kadranın üst satırı: tek satır metin.
struct WatchInlineComplication: View {
    let entry: PrayerEntry

    var body: some View {
        if let upcoming = entry.upcoming {
            let line = "\(upcoming.prayer.title) \(hhmm(upcoming.date))"
            // Çizili konum simgesi metnin BAŞINA giriyor: tek satır aile
            // kadranın genişliğine göre sondan kırpılıyor, sona eklenen bir
            // uyarı ilk kaybolan şey olurdu.
            if entry.isUsingFallbackLocation {
                Text("\(Image(systemName: "location.slash")) \(line)")
            } else {
                Text(line)
            }
        } else {
            Text("Ezan Vakti")
        }
    }
}
