import SwiftUI

@main
struct EzanVaktiApp: App {
    /// Takip kaydı ve saat köprüsü uygulama düzeyinde kuruluyor, kök görünümde
    /// değil: saatten gelen işaret uygulamayı arka planda uyandırıyor ve o anda
    /// bir pencere çizilmemiş olabiliyor. Köprü görünüme bağlı olsaydı işaret
    /// ancak kullanıcı uygulamayı bir dahaki açışında kaydedilirdi.
    ///
    /// `WCSession.delegate` zayıf tutuluyor; köprünün sahibi olan güçlü
    /// referans burası.
    @State private var log: PrayerLogStore
    @State private var watchSync: WatchSyncController
    /// Live Activity denetleyicisi de burada: arka plan temizliği uygulamayı
    /// pencere çizilmeden uyandırıyor, kök görünümde dursaydı görev
    /// tutunacak bir örnek bulamazdı.
    @State private var liveActivity = LiveActivityController()

    init() {
        let log = PrayerLogStore()
        _log = State(initialValue: log)
        _watchSync = State(initialValue: WatchSyncController(log: log))
    }

    var body: some Scene {
        WindowGroup {
            RootView(log: log, watchSync: watchSync, liveActivity: liveActivity)
                .preferredColorScheme(.dark)
        }
        // Vakit girince kilit ekranındaki geri sayımı kaldıran uyanma.
        // Kaydı `BGTaskScheduler.register` yerine bu değiştirici yapıyor;
        // SwiftUI sahnesine bağlı olduğu için uygulama yaşam döngüsüne elle
        // kanca takmak gerekmiyor.
        .backgroundTask(.appRefresh(LiveActivityController.cleanupTaskID)) {
            await liveActivity.cleanupExpired()
        }
    }
}
