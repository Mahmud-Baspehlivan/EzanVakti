import SwiftUI
import UserNotifications

/// Ana ekranın görsel gövdesi. Kabuktan (TimelineView, sheet, izin akışı) ayrı
/// tutuluyor ki `Tools/render` ile Xcode olmadan basılıp gözle denenebilsin.
struct PrayerTimesContent: View {
    let viewModel: PrayerTimesViewModel
    let preferences: NotificationPreferences
    /// Planlayıcının tamamı yerine yalnız gösterilecek iki değer alınıyor;
    /// böylece görünüm bildirim merkezine hiç dokunmadan render edilebiliyor.
    let notificationAuthorization: UNAuthorizationStatus
    let scheduledNotificationCount: Int
    let now: Date
    var onSelectLocation: () -> Void = {}

    private let accent = Palette.accent

    var body: some View {
        let day = viewModel.times(for: now)
        let current = day?.current(at: now)

        ZStack {
            Palette.background(for: current)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                hero
                if let day {
                    list(day: day, current: current)
                } else {
                    unavailableNotice
                }
                Spacer(minLength: 0)
                footer
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Başlık

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Button(action: onSelectLocation) {
                HStack(spacing: 5) {
                    Text(viewModel.locationName)
                        .scaledFont(17, weight: .semibold)
                    Image(systemName: "chevron.down")
                        .scaledFont(11, weight: .semibold)
                        .foregroundStyle(.white.opacity(0.45))
                }
                .foregroundStyle(.white)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Konum: \(viewModel.locationName)")
            .accessibilityHint("Konumu değiştirmek için dokun")

            Text("\(viewModel.gregorianDate(for: now))  ·  \(viewModel.hijriDate(for: now))")
                .scaledFont(13)
                .foregroundStyle(.white.opacity(0.45))

            if viewModel.isUsingFallbackLocation {
                Label("Konum kapalı — İstanbul · değiştirmek için dokun", systemImage: "location.slash")
                    .scaledFont(12)
                    .foregroundStyle(accent.opacity(0.85))
                    .padding(.top, 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    // MARK: - Sıradaki vakit

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let upcoming = viewModel.upcoming(at: now),
               let readout = viewModel.remainingReadout(at: now) {
                SectionLabel(text: upcoming.prayer.title, size: 13, tracking: 2.4)

                // Kahraman **kalan süre**, vaktin saati değil.
                //
                // Önce saat buradaydı ("asıl aranan bilgi bu" gerekçesiyle) ama
                // o sayı hemen aşağıdaki listede zaten yazıyor: ekranın en
                // büyük öğesi bir tekrar, listede hiç bulunmayan tek bilgi olan
                // kalan süre ise en küçüğüydü. Hiyerarşi tersti.
                //
                // Sayı büyük, birim küçük: düz "1 sa 46 dk" 68 pt'de taşıyor ve
                // birimsiz bırakmak da olmuyor — "6:21" altı saat mi altı
                // dakika mı, biçimden anlaşılmıyor.
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    ForEach(readout.parts) { part in
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(part.value)
                                .scaledFont(68, weight: .medium, design: .rounded)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text(part.unit)
                                .scaledFont(24, weight: .medium)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    Text("kaldı")
                        .scaledFont(18, weight: .medium)
                        .foregroundStyle(.white.opacity(0.45))
                }
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 4)

                // Vaktin saati desteğe indi. Simge onu bir saat olarak
                // etiketliyor; "16:53'te" yazmak istenirdi ama Türkçede
                // bulunma hâli eki saatin son okunan sayısına göre değişiyor
                // ("üçte" ama "yedide", "kırkta" ama "ellide") — sabit bir ek
                // zamanların yarısında yanlış olurdu.
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .scaledFont(13, weight: .medium)
                    Text(viewModel.formatted(upcoming.date))
                        .scaledFont(17, weight: .medium)
                        .monospacedDigit()
                }
                .foregroundStyle(.white.opacity(0.55))
                .padding(.top, 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 34)
        .padding(.bottom, 30)
        // Parçalara bölünmüş sayıyı VoiceOver "1 sa 46 dk" diye okuyor;
        // kısaltmalar ekran için, ses için değil.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(heroAccessibilityLabel)
    }

    private var heroAccessibilityLabel: String {
        guard let upcoming = viewModel.upcoming(at: now),
              let readout = viewModel.remainingReadout(at: now) else { return "" }
        return "\(upcoming.prayer.title) \(viewModel.formatted(upcoming.date)), "
            + "\(readout.spoken) kaldı"
    }

    // MARK: - Vakit listesi

    private func list(day: DailyPrayerTimes, current: Prayer?) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(height: 1)

            ForEach(day.ordered, id: \.prayer.id) { entry in
                let isCurrent = entry.prayer == current
                let isPast = entry.date <= now && !isCurrent

                HStack(spacing: 0) {
                    // Sol kenar çubuğu: seçili satırı arka plan lekesi yerine
                    // kenardan işaretlemek daha net okunuyor.
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(isCurrent ? accent : .clear)
                        .frame(width: 3, height: 20)
                        .padding(.trailing, 13)

                    Text(entry.prayer.title)
                        .scaledFont(16, weight: isCurrent ? .semibold : .regular)

                    Spacer(minLength: 8)

                    if preferences.enabled.contains(entry.prayer) {
                        Image(systemName: "bell.fill")
                            .scaledFont(9)
                            .foregroundStyle(.white.opacity(isPast ? 0.15 : 0.3))
                            .padding(.trailing, 8)
                            .accessibilityHidden(true)
                    }

                    Text(viewModel.formatted(entry.date))
                        .scaledFont(16, weight: isCurrent ? .semibold : .regular)
                        .monospacedDigit()
                }
                .foregroundStyle(.white.opacity(isCurrent ? 1 : (isPast ? 0.32 : 0.78)))
                // Sabit yükseklik yerine en az: büyük puntoda metin kırpılmasın.
                .frame(minHeight: 60)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(rowAccessibilityLabel(entry, isCurrent: isCurrent, isPast: isPast))

                if entry.prayer != day.ordered.last?.prayer {
                    Rectangle()
                        .fill(.white.opacity(0.06))
                        .frame(height: 1)
                        .padding(.leading, 16)
                }
            }
        }
    }

    /// Satırın tamamı tek cümle olarak okunuyor; ayrı ayrı "İkindi", "16:58",
    /// "zil" duymak bir şey anlatmıyor.
    private func rowAccessibilityLabel(
        _ entry: (prayer: Prayer, date: Date), isCurrent: Bool, isPast: Bool
    ) -> String {
        var parts = ["\(entry.prayer.title) \(viewModel.formatted(entry.date))"]
        if isCurrent { parts.append("şu anki vakit") }
        else if isPast { parts.append("geçti") }
        if preferences.enabled.contains(entry.prayer) { parts.append("bildirim açık") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Alt bilgi

    @ViewBuilder
    private var footer: some View {
        Group {
            switch notificationAuthorization {
            case .denied:
                Label("Bildirim izni kapalı", systemImage: "bell.slash")
                    .foregroundStyle(accent.opacity(0.85))
            case .authorized, .provisional:
                Label("\(scheduledNotificationCount) bildirim planlandı", systemImage: "bell")
                    .foregroundStyle(.white.opacity(0.3))
            default:
                EmptyView()
            }
        }
        .scaledFont(12)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 18)
    }

    private var unavailableNotice: some View {
        Text("Bu konum ve tarih için vakitler hesaplanamıyor. Yüksek enlemlerde sabah ve yatsı için ayrı bir yöntem seçilmesi gerekir.")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.65))
            .padding(.vertical, 24)
    }
}
