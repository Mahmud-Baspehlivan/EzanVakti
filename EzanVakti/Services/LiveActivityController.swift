import ActivityKit
import Foundation

/// Kilit ekranı ve Dinamik Ada geri sayımını yönetir.
///
/// **Bilinen sınır:** Live Activity arka planda kendiliğinden başlatılamıyor.
/// Sunucudan push göndermek gerekiyor, bizde sunucu yok. Bu yüzden etkinlik
/// uygulama öne geldiğinde sıradaki vakit için kuruluyor ve o vakit gelince
/// bayatlıyor; bir sonraki vaktin görünmesi için uygulamanın tekrar açılması
/// gerekiyor.
@MainActor
enum LiveActivityController {
    static var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Öne gelişte çağrılıyor: eskisini kapatıp sıradaki vakit için yenisini kurar.
    static func refresh(with content: PrayerActivityContent?, enabled: Bool) async {
        await endAll()
        guard enabled, isAvailable, let content, content.prayerTime > Date() else { return }

        do {
            _ = try Activity.request(
                attributes: PrayerActivityAttributes(),
                // Vakit girdikten sonra içerik anlamını yitiriyor; sistem bunu
                // bayat olarak işaretlesin diye staleDate veriliyor.
                content: ActivityContent(state: content, staleDate: content.prayerTime),
                pushType: nil
            )
        } catch {
            // İzin kapalıysa veya kota dolduysa sessizce vazgeçiliyor;
            // bu bir yan özellik, uygulamanın çalışmasını engellememeli.
        }
    }

    static func endAll() async {
        for activity in Activity<PrayerActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
