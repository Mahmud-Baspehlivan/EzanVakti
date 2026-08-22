import SwiftUI

struct NearbyMosquesView: View {
    let location: LocationProvider

    @State private var viewModel = NearbyMosquesViewModel()
    @State private var mode: NearbyMosquesMode = .list
    @State private var mapApp = MapAppPreferenceStore.app
    @State private var availableMapApps: [MapApp] = []

    private var mosques: [Mosque] {
        if case .loaded(let mosques) = viewModel.state { return mosques }
        return []
    }

    var body: some View {
        ZStack {
            Palette.background(for: nil)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                NearbyMosquesHeader(
                    locationName: viewModel.locationName,
                    radius: viewModel.radius,
                    mode: mode,
                    canShowMap: !mosques.isEmpty,
                    onSelectRadius: { viewModel.select($0) },
                    onToggleMode: { mode = mode.toggled }
                )
                .padding(.horizontal, 20)

                results

                // Sonuç yokken "Yol tarifi: ..." satırı bir işe yaramıyor,
                // yalnızca ekranı meşgul ediyor.
                if !mosques.isEmpty {
                    MapAppFooter(apps: availableMapApps, selected: mapApp, onSelect: selectMapApp)
                        .padding(.bottom, 6)
                }
            }
        }
        // Satırdaki ok pusulaya bağlı; sekmeden çıkınca kapanıyor.
        .onAppear {
            location.startHeading()
            viewModel.apply(location.state)
            availableMapApps = MapAppLauncher.available
        }
        .onDisappear { location.stopHeading() }
        .onChange(of: descriptor(of: location.state)) { _, _ in
            viewModel.apply(location.state)
        }
    }

    /// Harita yalnızca gösterecek camisi varken açılıyor; arama sürerken ve
    /// hata durumunda liste gövdesi devralıyor, yoksa boş harita sebep söylemiyor.
    @ViewBuilder
    private var results: some View {
        if mode == .map, !mosques.isEmpty, let center = viewModel.coordinate {
            NearbyMosquesMap(mosques: mosques, center: center,
                             showsUserLocation: !location.mode.isManual,
                             onSelect: openDirections)
                .padding(.horizontal, 20)
        } else {
            ScrollView {
                NearbyMosquesContent(
                    state: viewModel.state,
                    radius: viewModel.radius,
                    heading: location.heading,
                    onSelect: openDirections,
                    onRetry: retry
                )
                .padding(.horizontal, 20)
            }
            .refreshable { await viewModel.refresh() }
        }
    }

    /// Ulaşım biçimi seçili yarıçaptan geliyor: 1 km yürünür, 5 ve 25 km'de
    /// yaya tarifi anlamsız uzunlukta çıkıyor.
    private func openDirections(to mosque: Mosque) {
        MapAppLauncher.openDirections(to: mosque, using: mapApp,
                                      mode: viewModel.radius.travelMode)
    }

    private func selectMapApp(_ app: MapApp) {
        mapApp = app
        MapAppPreferenceStore.app = app
    }

    /// Hata konum izninden de gelebiliyor; koordinat olmadan arama yapılamıyor.
    private func retry() {
        location.start()
        viewModel.reload()
    }

    /// `onChange` için sade bir kimlik: LocationState eşitlenebilir değil.
    private func descriptor(of state: LocationState) -> String {
        switch state {
        case .resolved(let coordinate, let name):
            return "\(coordinate.latitude),\(coordinate.longitude),\(name)"
        case .denied:
            return "denied"
        case .failed(let message):
            return "failed:\(message)"
        case .idle:
            return "idle"
        case .requesting:
            return "requesting"
        }
    }
}
