import Foundation
import Observation
import UserNotifications

/// Vakit bildirimlerini planlar.
///
/// iOS bir uygulamaya en fazla 64 bekleyen yerel bildirim veriyor. Vakitler her gün
/// değiştiği için tekrarlayan tetikleyici kullanılamıyor; her vakit ayrı ayrı
/// planlanıyor ve bu da planlanabilen ufku sınırlıyor. Uygulama her öne geldiğinde
/// yeniden planlıyoruz — kullanıcı uygulamayı `horizonDays` boyunca hiç açmazsa
/// bildirimler kesilir. Sunucusuz bir tasarımda bunun etrafından dolaşmak mümkün değil.
@MainActor
@Observable
final class PrayerNotificationScheduler {
    /// 64'lük tavana bilerek pay bırakıyoruz.
    private static let budget = 58
    private static let horizonDays = 15

    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    private(set) var scheduledCount = 0
    private(set) var lastError: String?

    private let center = UNUserNotificationCenter.current()

    /// Süregelen planlama. Ayar sayfasında altı vakit anahtarını hızlıca açıp
    /// kapatmak, her biri `removeAllPendingNotificationRequests` + 58'e kadar
    /// `add` yapan altı örtüşen planlama başlatıyordu. Yenisi geldiğinde önceki
    /// iptal ediliyor: son istek kazanır.
    @ObservationIgnored private var pending: Task<Void, Never>?

    func refreshAuthorization() async {
        authorization = await center.notificationSettings().authorizationStatus
    }

    /// Kullanıcı reddettiyse tekrar sormanın anlamı yok; iOS ikinci kez sormaz.
    func requestAuthorizationIfNeeded() async {
        await refreshAuthorization()
        guard authorization == .notDetermined else { return }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            lastError = error.localizedDescription
        }
        await refreshAuthorization()
    }

    func reschedule(
        calculator: PrayerTimesCalculator,
        timeZone: TimeZone,
        locationName: String,
        preferences: NotificationPreferences,
        now: Date = Date()
    ) async {
        let previous = pending
        previous?.cancel()
        let task = Task { @MainActor in
            // İptal yetmiyor: önceki görev `center.add` üzerinde asılıysa, biz
            // `removeAllPendingNotificationRequests` yaptıktan sonra uyanıp bir
            // istek daha ekleyebilir ve o bayat bildirim hayatta kalır. İptal
            // edilen görev zaten hemen çıkacağı için beklemek ucuz.
            await previous?.value
            await self.performReschedule(
                calculator: calculator,
                timeZone: timeZone,
                locationName: locationName,
                preferences: preferences,
                now: now
            )
        }
        pending = task
        await task.value
    }

    private func performReschedule(
        calculator: PrayerTimesCalculator,
        timeZone: TimeZone,
        locationName: String,
        preferences: NotificationPreferences,
        now: Date
    ) async {
        guard authorization == .authorized || authorization == .provisional else {
            scheduledCount = 0
            return
        }

        center.removeAllPendingNotificationRequests()

        guard !preferences.enabled.isEmpty else {
            scheduledCount = 0
            return
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        // Bildirim kimliğinin gün parçası. `en_US_POSIX` burada da şart:
        // Gregoryen olmayan bir takvim yereliyle "yyyyMMdd" bambaşka bir dize
        // üretir, kimlikler kayar ve aynı vakit için mükerrer bildirim kalır.
        let dayKeyFormatter = DateFormatter()
        dayKeyFormatter.timeZone = timeZone
        dayKeyFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayKeyFormatter.dateFormat = "yyyyMMdd"
        // Gövdedeki saat için tek formatlayıcı: her bildirimde yeniden kurulunca
        // 58 kez bedeli ödeniyordu. `en_US_POSIX` şart — locale verilmezse
        // "24 Saat" ayarı kapalı cihazlarda "HH:mm" 1:30 PM'e dönüşüyor.
        let timeFormatter = DateFormatter()
        timeFormatter.timeZone = timeZone
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "HH:mm"

        var scheduled = 0

        for offset in 0..<Self.horizonDays {
            guard scheduled < Self.budget,
                  let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let times = calculator.times(for: day, in: timeZone)
            else { continue }

            for prayer in Prayer.allCases where preferences.enabled.contains(prayer) {
                // İptal edilmiş görev kalan eklemeleri yapmaya devam etmesin;
                // yerini alan planlama zaten ufku baştan kuruyor.
                guard !Task.isCancelled else { return }
                guard scheduled < Self.budget else { break }

                let fireDate = times[prayer]
                    .addingTimeInterval(-Double(preferences.minutesBefore) * 60)
                guard fireDate > now else { continue }

                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: fireDate
                )
                let request = UNNotificationRequest(
                    identifier: "prayer-\(prayer.rawValue)-\(dayKeyFormatter.string(from: day))",
                    content: content(for: prayer, at: times[prayer], place: locationName,
                                     preferences: preferences, formatter: timeFormatter),
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                )

                do {
                    try await center.add(request)
                    scheduled += 1
                } catch {
                    lastError = error.localizedDescription
                }
            }
        }

        scheduledCount = scheduled
    }

    private func content(
        for prayer: Prayer, at date: Date, place: String,
        preferences: NotificationPreferences, formatter: DateFormatter
    ) -> UNMutableNotificationContent {
        let minutesBefore = preferences.minutesBefore

        let content = UNMutableNotificationContent()
        content.title = minutesBefore > 0
            ? "\(prayer.title) vaktine \(minutesBefore) dakika"
            : "\(prayer.title) Vakti"
        content.body = "\(place) · \(formatter.string(from: date))"
        content.sound = NotificationSoundCatalog.sound(id: preferences.soundID).unSound
        // .timeSensitive odak modlarını aşar ama ayrı bir entitlement istiyor;
        // imzalamayı bozmamak için v1'de varsayılan seviyede bırakıldı.
        content.interruptionLevel = .active
        return content
    }
}
