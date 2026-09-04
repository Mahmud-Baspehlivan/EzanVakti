import SwiftUI

struct RootView: View {
    /// Konum sağlayıcı sekmeler arasında paylaşılıyor: tek CLLocationManager,
    /// tek izin sorusu.
    @State private var location = LocationProvider()
    /// Takip kaydı dışarıdan geliyor: saatten gelen işaretleri karşılayan köprü
    /// aynı örneği uygulama düzeyinde tutuyor, pencere çizilmeden önce de
    /// yazabilmesi gerekiyor.
    let log: PrayerLogStore
    /// Saat köprüsü yalnız hatasını göstermek için taşınıyor; işi arka planda,
    /// görünümden bağımsız yürüyor.
    let watchSync: WatchSyncController
    /// Uygulama düzeyinde kuruluyor; arka plan temizliği aynı örneğe uğruyor.
    let liveActivity: LiveActivityController
    /// Bunlar da kökte kuruluyor: `@State`'in başlangıç ifadesi `@autoclosure`
    /// değil, görünüm yapısı her yeniden kurulduğunda değerlendiriliyor. Sekme
    /// gövdesinde dursalardı her yeniden çizimde UserDefaults çözülürdü; kök bir
    /// kez kuruluyor.
    @State private var scheduler = PrayerNotificationScheduler()
    @State private var preferencesStore = NotificationPreferencesStore()

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

            TrackingView(log: log, location: location, watchSyncError: watchSync.lastError)
                .tabItem { Label("Takip", systemImage: "checklist") }
        }
        .task { location.start() }
    }
}
