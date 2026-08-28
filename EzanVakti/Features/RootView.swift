import SwiftUI

struct RootView: View {
    /// Konum sağlayıcı sekmeler arasında paylaşılıyor: tek CLLocationManager,
    /// tek izin sorusu.
    @State private var location = LocationProvider()
    /// Takip kaydı sekmeler ve ileride widget arasında paylaşılacak; tek kaynak.
    @State private var log = PrayerLogStore()
    /// Bunlar da kökte kuruluyor: `@State`'in başlangıç ifadesi `@autoclosure`
    /// değil, görünüm yapısı her yeniden kurulduğunda değerlendiriliyor. Sekme
    /// gövdesinde dursalardı her yeniden çizimde UserDefaults çözülürdü; kök bir
    /// kez kuruluyor.
    @State private var scheduler = PrayerNotificationScheduler()
    @State private var preferencesStore = NotificationPreferencesStore()
    @State private var liveActivity = LiveActivityController()

    var body: some View {
        TabView {
            PrayerTimesView(
                location: location,
                scheduler: scheduler,
                preferencesStore: preferencesStore,
                liveActivity: liveActivity
            )
            .tabItem { Label("Vakitler", systemImage: "clock") }

            QiblaView(location: location)
                .tabItem { Label("Kıble", systemImage: "location.north.line") }

            NearbyMosquesView(location: location)
                .tabItem { Label("Camiler", systemImage: "building.2") }

            ImsakiyeView(location: location)
                .tabItem { Label("İmsakiye", systemImage: "calendar") }

            TrackingView(log: log)
                .tabItem { Label("Takip", systemImage: "checklist") }
        }
        .task { location.start() }
    }
}
