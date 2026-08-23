import ActivityKit
import Foundation

/// Kilit ekranı ve Dinamik Ada geri sayımını yönetir.
///
/// iOS 26'dan itibaren etkinlikler **ileri bir tarihe zamanlanabiliyor** ve
/// sistem uygulama arka plandayken bile başlatıyor — sunucu gerekmiyor.
/// Daha eski sürümlerde `Activity.request` yalnızca uygulama öndeyken
/// çalıştığı için sıradaki vakit ancak lead penceresine girmişse kuruluyor;
/// oradan sonrası bir sonraki açılışa kalıyor.
@MainActor
enum LiveActivityController {
    /// Aynı anda kaç vakit için kurulacağı. Zamanlanmış etkinlikler de sistemin
    /// eşzamanlı etkinlik sınırına sayılıyor, o yüzden az tutuluyor.
    private static let scheduleCount = 3

    static var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    static func refresh(with contents: [PrayerActivityContent], enabled: Bool,
                        leadMinutes: Int) async {
        await endAll()
        guard enabled, isAvailable, !contents.isEmpty else { return }

        let lead = Double(leadMinutes) * 60
        let now = Date()

        for content in contents.prefix(scheduleCount) {
            let startAt = content.prayerTime.addingTimeInterval(-lead)
            let activityContent = ActivityContent(state: content, staleDate: content.prayerTime)

            if startAt <= now {
                // Pencere zaten açık: hemen kur.
                guard content.prayerTime > now else { continue }
                _ = try? Activity.request(
                    attributes: PrayerActivityAttributes(),
                    content: activityContent,
                    pushType: nil
                )
                continue
            }

            if #available(iOS 26.0, *) {
                // Sistem belirtilen anda başlatıyor, uygulama arka plandayken de.
                // `alertConfiguration` zorunlu: kullanıcı etkinliğin başladığını
                // bilsin diye Apple şart koşuyor.
                _ = try? Activity.request(
                    attributes: PrayerActivityAttributes(),
                    content: activityContent,
                    pushType: nil,
                    style: .standard,
                    alertConfiguration: AlertConfiguration(
                        title: "\(content.prayer.title) yaklaşıyor",
                        body: "\(content.prayer.title) vaktine \(leadMinutes) dakika kaldı.",
                        sound: .default
                    ),
                    start: startAt
                )
            }
            // iOS 26 öncesi: zamanlama yok. Yalnızca pencere açıkken kurulan
            // etkinlik gösterilir, gerisi bir sonraki uygulama açılışına kalır.
        }
    }

    static func endAll() async {
        for activity in Activity<PrayerActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
