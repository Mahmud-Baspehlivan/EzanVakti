import SwiftUI

struct RootView: View {
    /// Konum sağlayıcı sekmeler arasında paylaşılıyor: tek CLLocationManager,
    /// tek izin sorusu.
    @State private var location = LocationProvider()
    /// Takip kaydı sekmeler ve ileride widget arasında paylaşılacak; tek kaynak.
    @State private var log = PrayerLogStore()

    var body: some View {
        TabView {
            PrayerTimesView(location: location)
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
