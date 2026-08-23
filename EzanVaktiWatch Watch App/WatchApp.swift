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
        TimelineView(.periodic(from: .now, by: 1)) { context in
            WatchPrayerTimesView(viewModel: viewModel, now: context.date)
        }
        .onAppear { location.start() }
        .onChange(of: locationKey) { _, _ in
            guard let coordinate = location.coordinate else { return }
            viewModel.apply(coordinate: coordinate, name: location.name)
            // Komplikasyon aynı konumu kullansın (saatin kendi App Group'u).
            SharedLocationStore.save(coordinate: coordinate, name: location.name)
        }
    }

    private var locationKey: String {
        guard let c = location.coordinate else { return "yok" }
        return "\(c.latitude),\(c.longitude),\(location.name)"
    }
}
