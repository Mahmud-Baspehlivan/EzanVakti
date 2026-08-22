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
                        .font(.system(size: 17, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .foregroundStyle(.white)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("\(viewModel.gregorianDate(for: now))  ·  \(viewModel.hijriDate(for: now))")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.45))

            if viewModel.isUsingFallbackLocation {
                Label("Konum kapalı — İstanbul · değiştirmek için dokun", systemImage: "location.slash")
                    .font(.system(size: 12))
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
            if let upcoming = viewModel.upcoming(at: now) {
                SectionLabel(text: upcoming.prayer.title, size: 13, tracking: 2.4)

                // Saat kahraman: asıl aranan bilgi bu, geri sayım destek.
                Text(viewModel.formatted(upcoming.date))
                    .font(.system(size: 68, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 6)

                HStack(spacing: 5) {
                    Text(viewModel.remaining(at: now))
                        .contentTransition(.numericText())
                    Text(viewModel.remainingCaption(at: now))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .font(.system(size: 16, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.62))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 34)
        .padding(.bottom, 30)
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
                        .font(.system(size: 16, weight: isCurrent ? .semibold : .regular))

                    Spacer(minLength: 8)

                    if preferences.enabled.contains(entry.prayer) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(isPast ? 0.15 : 0.3))
                            .padding(.trailing, 8)
                    }

                    Text(viewModel.formatted(entry.date))
                        .font(.system(size: 16, weight: isCurrent ? .semibold : .regular))
                        .monospacedDigit()
                }
                .foregroundStyle(.white.opacity(isCurrent ? 1 : (isPast ? 0.32 : 0.78)))
                .frame(height: 60)

                if entry.prayer != day.ordered.last?.prayer {
                    Rectangle()
                        .fill(.white.opacity(0.06))
                        .frame(height: 1)
                        .padding(.leading, 16)
                }
            }
        }
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
        .font(.system(size: 12))
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
