import SwiftUI

struct PrayerTimesView: View {
    let location: LocationProvider

    @State private var viewModel = PrayerTimesViewModel()
    @State private var scheduler = PrayerNotificationScheduler()
    @State private var preferencesStore = NotificationPreferencesStore()
    @State private var isShowingSettings = false
    @State private var isShowingLocationPicker = false

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        // Geri sayım saniye başı yenileniyor; TimelineView kendi Timer'ımızı
        // kurmaktan hem daha az kod hem de arka planda daha uysal.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            PrayerTimesContent(
                viewModel: viewModel,
                preferences: preferencesStore.preferences,
                notificationAuthorization: scheduler.authorization,
                scheduledNotificationCount: scheduler.scheduledCount,
                now: context.date,
                onSelectLocation: { isShowingLocationPicker = true }
            )
        }
        .overlay(alignment: .topTrailing) {
            Button {
                isShowingSettings = true
            } label: {
                Image(systemName: "bell.badge")
                    .scaledFont(16, weight: .medium)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(12)
            }
            .padding(.trailing, 8)
            .accessibilityLabel("Bildirim ayarları")
        }
        .sheet(isPresented: $isShowingSettings) {
            NotificationSettingsView(store: preferencesStore, scheduler: scheduler)
        }
        .sheet(isPresented: $isShowingLocationPicker) {
            LocationPickerView(location: location)
        }
        .task {
            await scheduler.requestAuthorizationIfNeeded()
            await reschedule()
        }
        .onChange(of: descriptor(of: location.state)) { _, _ in
            viewModel.apply(location.state)
            Task { await reschedule() }
        }
        .onChange(of: preferencesStore.preferences) { _, _ in
            Task { await reschedule() }
        }
        .onChange(of: scenePhase) { _, phase in
            // Ufuk 64 bildirimle sınırlı; her öne gelişte pencereyi ileri kaydırıyoruz.
            guard phase == .active else { return }
            Task {
                await scheduler.refreshAuthorization()
                await reschedule()
            }
        }
    }

    private func reschedule() async {
        await scheduler.reschedule(
            calculator: viewModel.calculator,
            timeZone: viewModel.timeZone,
            locationName: viewModel.locationName,
            preferences: preferencesStore.preferences
        )
    }

    /// `onChange` için sade bir kimlik: LocationState eşitlenebilir değil.
    private func descriptor(of state: LocationState) -> String {
        switch state {
        case .idle: return "idle"
        case .requesting: return "requesting"
        case .denied: return "denied"
        case .failed(let message): return "failed:\(message)"
        case .resolved(let coordinate, let name):
            return "resolved:\(coordinate.latitude),\(coordinate.longitude),\(name)"
        }
    }
}

#Preview {
    PrayerTimesView(location: LocationProvider())
}
