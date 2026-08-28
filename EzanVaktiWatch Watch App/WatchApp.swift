import SwiftUI

@main
struct EzanVaktiWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}

/// Saatte tek ekran var: vakitler.
///
/// Kıble bilerek yok — bileği kıbleye çevirmek için kolu tuhaf bir açıda
/// sabitlemek gerekiyor ve pusula bilekte daha az güvenilir. Kıble bir konumda
/// bir kez bulunan, tekrarlanmayan bir iş; saatin değeri bir bakışta alınan
/// tekrarlı bilgide.
struct WatchRootView: View {
    @State private var viewModel = WatchPrayerTimesModel()
    @State private var location = WatchLocationProvider()

    var body: some View {
        // Dakikada bir: geri sayım `Text(timerInterval:)` ile kendi kendine
        // ilerlediği için saniyelik tetiğe ihtiyacı yok. Yeniden çizim yalnızca
        // ızgaradaki "şu anki vakit" vurgusu ve geçmiş vakitlerin solması için
        // gerekiyor, ikisi de dakikalık. Saniyede bir tam ekran yeniden çizmek
        // bilekteki pili doğrudan yakıyordu.
        TimelineView(.prayerBoundaries(viewModel.upcomingBoundaries(after: .now))) { context in
            WatchPrayerTimesView(viewModel: viewModel, now: context.date)
        }
        .onAppear { location.start() }
        .onChange(of: locationKey) { _, _ in
            guard let coordinate = location.coordinate else { return }
            // Komplikasyonun okuduğu paylaşılan depoyu sağlayıcı kendi yazıyor.
            viewModel.apply(coordinate: coordinate, name: location.name)
        }
    }

    private var locationKey: String {
        guard let c = location.coordinate else { return "yok" }
        return "\(c.latitude),\(c.longitude),\(location.name)"
    }
}

/// Dakikalık tikler + günün vakit anları.
///
/// Yalnız `.everyMinute` yetmiyordu: ızgaradaki "şu anki vakit" vurgusu, vakit
/// girdikten sonra ancak bir sonraki dakika sınırında güncelleniyordu — yani 59
/// saniyeye kadar geç. Ezanın okunduğu an ekranın hâlâ önceki vakti işaretlemesi
/// tam da bu ekranın söylemesi gereken şeyi geciktiriyor.
///
/// Saniyelik çizelgeye dönmek de çözüm değil (watchOS'ta saniyede bir tam ekran
/// yeniden çizim doğrudan pil demek). Vakitler belirlenimci olduğu için sınırlar
/// önceden biliniyor; dakikalık bütçeyi bozmadan aralarına ekleniyorlar.
struct PrayerBoundarySchedule: TimelineSchedule {
    let boundaries: [Date]

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        var minutes = EveryMinuteTimelineSchedule()
            .entries(from: startDate, mode: mode)
            .makeIterator()
        var pending = boundaries.filter { $0 > startDate }.sorted()
        var nextMinute = minutes.next()

        return AnyIterator {
            guard let minute = nextMinute else { return nil }
            if let boundary = pending.first, boundary <= minute {
                pending.removeFirst()
                // Sınır tam dakikaya denk geldiyse tiki de tüket; aynı anı iki kez
                // yayımlamanın kimseye faydası yok.
                if boundary == minute { nextMinute = minutes.next() }
                return boundary
            }
            nextMinute = minutes.next()
            return minute
        }
    }
}

extension TimelineSchedule where Self == PrayerBoundarySchedule {
    static func prayerBoundaries(_ dates: [Date]) -> PrayerBoundarySchedule {
        PrayerBoundarySchedule(boundaries: dates)
    }
}
