import SwiftUI
import WidgetKit

extension PrayerEntry: TimelineEntry {}

struct PrayerTimesProvider: TimelineProvider {
    private var timeZone: TimeZone { .current }

    /// Paylaşılan konum yoksa İstanbul'a düşüyoruz ama bunu gizlemiyoruz.
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

        // Vakitler belirlenimci olduğu için çizelgeyi bir gün ileriye kadar
        // baştan üretebiliyoruz — ağ yok, tahmin yok.
        //
        // Girdiler yalnızca vakit geçişlerinde: geri sayım metni kendi kendine
        // ilerlediğinden dakikalık girdi üretmeye gerek yok. WidgetKit'in girdi
        // bütçesini böylece harcamıyoruz.
        var boundaries: [Date] = [now]
        let calculator = PrayerTimesCalculator(coordinate: coordinate, parameters: .diyanet)
        for dayOffset in 0...1 {
            let day = now.addingTimeInterval(Double(dayOffset) * 24 * 3600)
            guard let times = calculator.times(for: day, in: timeZone) else { continue }
            boundaries.append(contentsOf: times.ordered.map(\.date))
        }

        let horizon = now.addingTimeInterval(24 * 3600)
        let dates = boundaries
            .filter { $0 >= now && $0 <= horizon }
            .sorted()

        let entries = dates.map {
            PrayerEntry.make(at: $0, coordinate: coordinate, name: name,
                             timeZone: timeZone, isFallback: isFallback)
        }

        // Girdi üretilemezse (kutup bölgesi vb.) widget'ın donup kalmaması için
        // yine de bir yenileme noktası bırakıyoruz.
        guard !entries.isEmpty else {
            let fallback = PrayerEntry.make(at: now, coordinate: coordinate, name: name,
                                            timeZone: timeZone, isFallback: isFallback)
            completion(Timeline(entries: [fallback], policy: .after(now.addingTimeInterval(3600))))
            return
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct PrayerTimesWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            RectangularWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        case .accessoryInline:
            InlineWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        case .systemMedium:
            MediumWidgetView(entry: entry)
                .containerBackground(for: .widget) { homeBackground }
        default:
            SmallWidgetView(entry: entry)
                .containerBackground(for: .widget) { homeBackground }
        }
    }

    private var homeBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.07, green: 0.09, blue: 0.20),
                     Color(red: 0.14, green: 0.16, blue: 0.31)],
            startPoint: .top, endPoint: .bottom
        )
    }
}

struct PrayerTimesWidget: Widget {
    private let kind = "PrayerTimesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimesProvider()) { entry in
            PrayerTimesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Namaz Vakti")
        .description("Sıradaki vakti ve kalan süreyi gösterir.")
        .supportedFamilies([
            .accessoryInline, .accessoryCircular, .accessoryRectangular,
            .systemSmall, .systemMedium,
        ])
    }
}

@main
struct EzanVaktiWidgetBundle: WidgetBundle {
    var body: some Widget {
        PrayerTimesWidget()
    }
}
