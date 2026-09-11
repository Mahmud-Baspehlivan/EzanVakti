import SwiftUI

struct PrayerTimesView: View {
    let location: LocationProvider
    /// Planlayıcı ve tercihler kökte kuruluyor; burada `@State` olsalardı
    /// başlangıç ifadeleri her yeniden çizimde boşuna çalışırdı.
    let scheduler: PrayerNotificationScheduler
    let preferencesStore: NotificationPreferencesStore
    let liveActivity: LiveActivityController

    @State private var viewModel = PrayerTimesViewModel()
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
            NotificationSettingsView(store: preferencesStore, scheduler: scheduler,
                                     liveActivity: liveActivity)
        }
        .sheet(isPresented: $isShowingLocationPicker) {
            LocationPickerView(location: location)
        }
        .task {
            await scheduler.requestAuthorizationIfNeeded()
            await reschedule()
            await refreshLiveActivity()
        }
        .onChange(of: location.state) { _, _ in
            viewModel.apply(location.state)
            // Etkinlik de yenileniyor: konum değişince vakitler tamamen
            // değişiyor ama etkinlik eski şehrin içeriğini taşımaya devam
            // ediyordu. Elle başka bir şehir seçip uygulamada kalan kullanıcı
            // için kilit ekranı sessizce yanlış — ya da hiç kurulmamış olarak
            // kalıyordu; bildirimler yenilenirken etkinliğin atlanması gözden
            // kaçmış.
            Task {
                await reschedule()
                await refreshLiveActivity()
            }
        }
        .onChange(of: preferencesStore.preferences) { old, new in
            // Ayar sayfası bir sheet; kapanması scenePhase'i değiştirmiyor. Etkinliği
            // burada yenilemezsek kullanıcı "Kilit ekranında geri sayım"ı kapattığında
            // etkinlik olduğu yerde kalıyor — kapatılamayan bir kilit ekranı bileşeni.
            //
            // Ama yalnızca etkinliğin okuduğu iki alan için: yenileme önce hepsini
            // kapatıp yeniden kuruyor, yani ses ya da vakit anahtarı değiştirmek de
            // kilit ekranındaki geri sayımı boş yere yıkıp yeniden kurardı.
            let activityChanged = old.liveActivityEnabled != new.liveActivityEnabled
                || old.liveActivityLeadMinutes != new.liveActivityLeadMinutes
            Task {
                await reschedule()
                if activityChanged { await refreshLiveActivity() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Ufuk 64 bildirimle sınırlı; her öne gelişte pencereyi ileri kaydırıyoruz.
            guard phase == .active else { return }
            Task {
                await scheduler.refreshAuthorization()
                await reschedule()
                await refreshLiveActivity()
            }
        }
    }

    /// Live Activity arka planda kurulamıyor; her öne gelişte sıradaki vakte
    /// yeniden kuruluyor.
    private func refreshLiveActivity() async {
        await liveActivity.refresh(
            with: PrayerActivityContent.upcoming(
                count: 3,
                leadMinutes: preferencesStore.preferences.liveActivityLeadMinutes,
                coordinate: viewModel.coordinate,
                locationName: viewModel.locationName,
                timeZone: viewModel.timeZone
            ),
            enabled: preferencesStore.preferences.liveActivityEnabled
        )
    }

    private func reschedule() async {
        await scheduler.reschedule(
            calculator: viewModel.calculator,
            timeZone: viewModel.timeZone,
            locationName: viewModel.locationName,
            preferences: preferencesStore.preferences
        )
    }
}

#Preview {
    PrayerTimesView(
        location: LocationProvider(),
        scheduler: PrayerNotificationScheduler(),
        preferencesStore: NotificationPreferencesStore(),
        liveActivity: LiveActivityController()
    )
}
