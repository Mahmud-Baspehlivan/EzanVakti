import ActivityKit
import Foundation
import Observation

/// Kilit ekranı ve Dinamik Ada geri sayımını yönetir.
///
/// iOS 26'dan itibaren etkinlikler **ileri bir tarihe zamanlanabiliyor** ve
/// sistem uygulama arka plandayken bile başlatıyor — sunucu gerekmiyor.
/// Daha eski sürümlerde `Activity.request` yalnızca uygulama öndeyken
/// çalıştığı için sıradaki vakit ancak lead penceresine girmişse kuruluyor;
/// oradan sonrası bir sonraki açılışa kalıyor.
/// Ayrı bir örnek, statik ad alanı değil: `lastError` ancak izlenebilir bir
/// sahibin üzerindeyken ayarlar ekranı onu görebiliyor, ayrıca süregelen
/// yenileme durumu genel değişken olmaktan çıkıyor.
@MainActor
@Observable
final class LiveActivityController {
    /// Aynı anda kaç vakit için kurulacağı. Zamanlanmış etkinlikler de sistemin
    /// eşzamanlı etkinlik sınırına sayılıyor, o yüzden az tutuluyor.
    private static let scheduleCount = 3

    /// Süregelen yenileme. `apply` önce her şeyi kapatıp yeniden kurduğu için
    /// atomik değil: açılışta `.task` ile `scenePhase == .active` neredeyse aynı
    /// anda tetikleniyor ve iki yenileme her `await` noktasında birbirinin
    /// arasına giriyordu — ya biri diğerinin kurduğunu siliyor ya da aynı vakit
    /// için iki etkinlik kalıp Dinamik Ada minimal moda düşüyordu. Yenilemeler
    /// tek zincire dizilerek seri hale getiriliyor.
    @ObservationIgnored private var inFlight: Task<Void, Never>?

    /// Son yenilemenin hatası. Etkinlik sınırı aşıldığında ya da kullanıcı
    /// sistem ayarlarından kapattığında `Activity.request` fırlatıyor; sessizce
    /// yutulursa kilit ekranının neden boş kaldığı anlaşılmıyor.
    private(set) var lastError: String?

    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func refresh(with contents: [PrayerActivityContent], enabled: Bool,
                        leadMinutes: Int) async {
        let previous = inFlight
        let task = Task { @MainActor [self] in
            await previous?.value
            await apply(with: contents, enabled: enabled, leadMinutes: leadMinutes)
        }
        inFlight = task
        await task.value
    }

    private func apply(with contents: [PrayerActivityContent], enabled: Bool,
                              leadMinutes: Int) async {
        await endAll()

        guard enabled else {
            // Kullanıcı kendi kapattı; eski uyarı ekranda asılı kalmasın.
            lastError = nil
            return
        }
        guard isAvailable else {
            lastError = "Canlı Etkinlikler sistem ayarlarından kapalı."
            return
        }
        guard !contents.isEmpty else {
            lastError = nil
            return
        }

        // Tek bir vaktin kurulamaması yenilemeyi durdurmuyor; kalanlar denendikten
        // sonra son hata yazılıyor, hepsi başarılıysa alan temizleniyor.
        var failure: String?
        let lead = Double(leadMinutes) * 60
        let now = Date()

        for content in contents.prefix(Self.scheduleCount) {
            let startAt = content.prayerTime.addingTimeInterval(-lead)
            let activityContent = ActivityContent(state: content, staleDate: content.prayerTime)

            if startAt <= now {
                // Pencere zaten açık: hemen kur.
                guard content.prayerTime > now else { continue }
                do {
                    _ = try Activity.request(
                        attributes: PrayerActivityAttributes(),
                        content: activityContent,
                        pushType: nil
                    )
                } catch {
                    failure = error.localizedDescription
                }
                continue
            }

            if #available(iOS 26.0, *) {
                // Sistem belirtilen anda başlatıyor, uygulama arka plandayken de.
                // `alertConfiguration` zorunlu: kullanıcı etkinliğin başladığını
                // bilsin diye Apple şart koşuyor.
                do {
                    _ = try Activity.request(
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
                } catch {
                    failure = error.localizedDescription
                }
            }
            // iOS 26 öncesi: zamanlama yok. Yalnızca pencere açıkken kurulan
            // etkinlik gösterilir, gerisi bir sonraki uygulama açılışına kalır.
        }

        lastError = failure
    }

    func endAll() async {
        for activity in Activity<PrayerActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
