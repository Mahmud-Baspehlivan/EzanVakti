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
        let dayKeyFormatter = DateFormatter()
        dayKeyFormatter.timeZone = timeZone
        dayKeyFormatter.dateFormat = "yyyyMMdd"

        var scheduled = 0

        for offset in 0..<Self.horizonDays {
            guard scheduled < Self.budget,
                  let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let times = calculator.times(for: day, in: timeZone)
            else { continue }

            for prayer in Prayer.allCases where preferences.enabled.contains(prayer) {
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
                                     preferences: preferences, timeZone: timeZone),
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
        preferences: NotificationPreferences, timeZone: TimeZone
    ) -> UNMutableNotificationContent {
        let minutesBefore = preferences.minutesBefore
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"

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
