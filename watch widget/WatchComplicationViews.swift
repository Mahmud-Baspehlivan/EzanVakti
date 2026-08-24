import SwiftUI
import WidgetKit

/// Kadran komplikasyonları. Saf SwiftUI — `Tools/render` ile denetlenebiliyor.
///
/// Komplikasyonlar sistem tarafından tek renge tonlanıyor, o yüzden altın vurgu
/// kullanılmıyor. Geri sayım ve halka `timerInterval` alan sürümlerle kuruluyor:
/// zaman çizelgesi yalnızca vakit geçişlerinde girdi ürettiği için durağan bir
/// gösterge saatlerce donuk kalırdı.

private let complicationFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter
}()

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
                Text(timerInterval: previous...upcoming.date, countsDown: true)
                    .font(.system(size: 11))
                    .monospacedDigit()
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
            Text("\(upcoming.prayer.title) \(hhmm(upcoming.date))")
        } else {
            Text("Ezan Vakti")
        }
    }
}
