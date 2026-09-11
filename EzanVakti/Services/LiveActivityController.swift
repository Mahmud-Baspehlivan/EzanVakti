import ActivityKit
import BackgroundTasks
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

    /// Arka plan temizliğinin görev kimliği.
    ///
    /// `Info.plist`'teki `BGTaskSchedulerPermittedIdentifiers` girdisiyle birebir
    /// aynı olmak zorunda; ayrışırsa `submit` sessizce değil, fırlatarak
    /// başarısız oluyor.
    static let cleanupTaskID = "com.mahmud.ezanvakti.activity-cleanup"

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

    func refresh(with contents: [PrayerActivityContent], enabled: Bool) async {
        let previous = inFlight
        let task = Task { @MainActor [self] in
            await previous?.value
            await apply(with: contents, enabled: enabled)
        }
        inFlight = task
        await task.value
    }

    private func apply(with contents: [PrayerActivityContent], enabled: Bool) async {
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
        let now = Date()

        for content in contents.prefix(Self.scheduleCount) {
            // Pencerenin başı içerikten okunuyor, burada yeniden
            // hesaplanmıyor: geri sayım ve ilerleme çubuğu da aynı aralığı
            // kullanıyor, yani etkinlik tam çubuk boşken açılıyor. Lead'i iki
            // yerde ayrı ayrı uygulamak ikisinin ayrışmasına açık kapı olurdu.
            let startAt = content.windowStart
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
                    // NOT: burada bir ara `end(dismissalPolicy: .after(prayerTime))`
                    // denendi — vakit girince etkinlik kendiliğinden kalksın diye.
                    // Cihazda etkinlik hiç görünmedi ve geri alındı: `end` çağrısı
                    // etkinliği `.ended` durumuna geçiriyor ve sonlandırılmış bir
                    // etkinlik Dinamik Ada'da sunulmuyor. Vakit geçtikten sonra
                    // asılı kalma sorunu bu yüzden duruyor; sunucusuz tek
                    // alternatif `BackgroundTasks`.
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
                            // Ayarlanan lead değil, pencerenin gerçek uzunluğu:
                            // pencere önceki vakitte kesildiğinde ("3 saat"
                            // seçiliyken Akşam–Yatsı 79 dakika) ikisi ayrışıyor
                            // ve bildirim olmayan bir süreyi söylüyordu.
                            body: "\(content.prayer.title) vaktine \(Int(content.prayerTime.timeIntervalSince(startAt) / 60)) dakika kaldı.",
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
        // Kurulan etkinliklerin ilk vaktine uyanma isteği bırakılıyor.
        scheduleCleanup(after: now)
    }

    // MARK: - Arka plan temizliği

    /// Vakti geçmiş etkinlikleri sonlandırır, sonra bir sonraki vakte uyanma
    /// isteği bırakır.
    ///
    /// Neden bu var: `staleDate` etkinliği ekrandan kaldırmıyor ve sunucumuz
    /// olmadığı için push ile de sonlandıramıyoruz. Apple'ın `end` belgesi tam
    /// olarak bu yolu gösteriyor — "uygulama önde ya da arka plandayken".
    ///
    /// **Garanti değil, en iyi çaba.** `BGAppRefreshTask` fırsatçı çalışıyor:
    /// sistem `earliestBeginDate`'ten önce çalıştırmıyor ama sonrasında ne zaman
    /// çalıştıracağı onun kararı. Çalışmazsa sonuç eskisiyle aynı — etkinlik
    /// uygulama bir dahaki açılışında siliniyor — yani gerilemesi yok.
    ///
    /// Kurulur kurulmaz `end(dismissalPolicy: .after(...))` çağırmak da denendi
    /// ve geri alındı: `.ended` durumundaki etkinlik Dinamik Ada'da hiç
    /// sunulmuyor, yani geç kapanan bir etkinlik yerine hiç açılmayan bir
    /// etkinlik oluyordu.
    func cleanupExpired(now: Date = Date()) async {
        for activity in Activity<PrayerActivityAttributes>.activities
        where activity.content.state.prayerTime <= now {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        scheduleCleanup(after: now)
    }

    /// Elde kalan en yakın vakit anına uyanma isteği bırakır.
    ///
    /// Sıradaki vakit elde kalan etkinliklerden okunuyor, yeniden hesaplanmıyor:
    /// temizlenecek şey zaten onlar, başka bir kaynağa bakmak ikisinin ayrışma
    /// ihtimalini açardı.
    private func scheduleCleanup(after now: Date) {
        let next = Activity<PrayerActivityAttributes>.activities
            .map(\.content.state.prayerTime)
            .filter { $0 > now }
            .min()
        guard let next else { return }

        let request = BGAppRefreshTaskRequest(identifier: Self.cleanupTaskID)
        request.earliestBeginDate = next
        do {
            // Aynı kimlikle bekleyen istek varsa yenisi onun yerini alıyor.
            try BGTaskScheduler.shared.submit(request)
            cleanupError = nil
        } catch {
            // Ölümcül değil: etkinlik yine çalışıyor, yalnız kendiliğinden
            // kalkmıyor. Yine de sessiz kalmıyoruz — en sık sebebi kullanıcının
            // "Arka Planda Yenileme"yi kapatmış olması ve bu bilinebilir bir şey.
            cleanupError = "Arka plan temizliği planlanamadı: \(error.localizedDescription)"
        }
    }

    /// Arka plan temizliğinin planlanamama sebebi. `lastError`'dan ayrı duruyor:
    /// o etkinliğin hiç kurulamadığını söylüyor, bu yalnız geç kalkacağını.
    private(set) var cleanupError: String?

    func endAll() async {
        for activity in Activity<PrayerActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
