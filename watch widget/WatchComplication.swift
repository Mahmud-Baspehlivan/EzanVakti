import SwiftUI
import WidgetKit

/// Kadran komplikasyonu.
///
/// Zaman çizelgesi telefondaki widget ile aynı mantıkta: vakitler belirlenimci
/// olduğu için girdiler bir gün ileriye kadar baştan üretiliyor ve yalnızca
/// vakit geçişlerinde konuyor. Geri sayım kendi kendine ilerlediğinden
/// dakikalık girdiye gerek yok.
struct WatchComplicationProvider: TimelineProvider {
    /// `.autoupdatingCurrent`: kullanıcı uçakla dilim değiştirdiğinde çizelge
    /// bir sonraki yenilemede doğru dilimi görsün.
    private var timeZone: TimeZone { .autoupdatingCurrent }

    /// Saat kendi konumunu kendisi çözüyor; telefonla veri paylaşmıyor.
    private func resolveLocation() -> (Coordinate, String, Bool) {
        if let shared = SharedLocationStore.load() {
            return (shared.coordinate, shared.name, false)
        }
        return (.istanbul, "İstanbul", true)
    }

    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry.make(at: Date(), coordinate: .istanbul, name: "İstanbul",
                         timeZone: timeZone, isFallback: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        let (coordinate, name, isFallback) = resolveLocation()
        completion(PrayerEntry.make(at: Date(), coordinate: coordinate, name: name,
                                    timeZone: timeZone, isFallback: isFallback))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let now = Date()
        let (coordinate, name, isFallback) = resolveLocation()
        let calculator = PrayerTimesCalculator(coordinate: coordinate, parameters: .diyanet)

        var boundaries: [Date] = [now]
        for dayOffset in 0...1 {
            let day = now.addingTimeInterval(Double(dayOffset) * 24 * 3600)
            guard let times = calculator.times(for: day, in: timeZone) else { continue }
            boundaries.append(contentsOf: times.ordered.map(\.date))
        }

        let horizon = now.addingTimeInterval(24 * 3600)
        let entries = boundaries
            .filter { $0 >= now && $0 <= horizon }
            .sorted()
            .map {
                PrayerEntry.make(at: $0, coordinate: coordinate, name: name,
                                 timeZone: timeZone, isFallback: isFallback)
            }

        guard !entries.isEmpty else {
            let fallback = PrayerEntry.make(at: now, coordinate: coordinate, name: name,
                                            timeZone: timeZone, isFallback: isFallback)
            completion(Timeline(entries: [fallback], policy: .after(now.addingTimeInterval(3600))))
            return
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct WatchComplicationEntryView: View {
    @Environment(\.widgetFamily) private var family
    /// Sistemin uygulayacağı pay. `contentMarginsDisabled()` onu kapatıyor ama
    /// bu değer okunabilir kalıyor; böylece hangi ailede hangi kenarın payı
    /// geri verileceğine tek tek karar verilebiliyor.
    @Environment(\.widgetContentMargins) private var margins
    let entry: PrayerEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            WatchCircularComplication(entry: entry)
                .padding(margins)
                .containerBackground(.clear, for: .widget)
        case .accessoryCorner:
            WatchCornerComplication(entry: entry)
                .padding(margins)
                .containerBackground(.clear, for: .widget)
        case .accessoryInline:
            WatchInlineComplication(entry: entry)
                .padding(margins)
                .containerBackground(.clear, for: .widget)
        default:
            // Dikdörtgende yalnız yatay pay geri veriliyor. Dikey payı sistem
            // içeriğin altına ve üstüne ölü bant olarak koyuyordu; bu ailede
            // yuvanın tamamı kullanılıyor, hizayı içeriğin kendisi kuruyor.
            WatchRectangularComplication(entry: entry)
                .padding(.horizontal, margins.leading)
                .containerBackground(.clear, for: .widget)
        }
    }
}

struct WatchComplication: Widget {
    private let kind = "EzanVaktiComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchComplicationProvider()) { entry in
            WatchComplicationEntryView(entry: entry)
        }
        // Sistem payı kapatılıyor, geri vermek `WatchComplicationEntryView`'in
        // işi. Ayar bütün ailelere birden uygulanıyor — tek tek kapatılamıyor,
        // o yüzden karar aile başına orada veriliyor.
        .contentMarginsDisabled()
        .configurationDisplayName("Namaz Vakti")
        .description("Sıradaki vakti ve kalan süreyi gösterir.")
        .supportedFamilies([
            .accessoryCircular, .accessoryCorner,
            .accessoryRectangular, .accessoryInline,
        ])
    }
}

@main
struct EzanVaktiComplicationBundle: WidgetBundle {
    var body: some Widget {
        WatchComplication()
    }
}
