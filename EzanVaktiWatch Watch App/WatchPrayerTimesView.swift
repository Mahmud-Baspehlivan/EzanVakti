import SwiftUI

/// Saatteki ana ekran.
///
/// Telefon uygulamasının küçültülmüş hâli değil: 45 mm ekranda ~198×242 pt yer
/// var, o yüzden hiyerarşi tek bir soruya indirgendi — sıradaki vakte ne kadar
/// kaldı. Liste altında, kaydırarak görülüyor.
struct WatchPrayerTimesView: View {
    let viewModel: WatchPrayerTimesModel
    let now: Date

    var body: some View {
        ScrollView {
            WatchPrayerTimesContent(viewModel: viewModel, now: now)
        }
    }
}

/// Kaydırma kabuğundan ayrı: `ImageRenderer` ScrollView içeriğini basmıyor,
/// bu haliyle saat ekranı Xcode olmadan denetlenebiliyor.
struct WatchPrayerTimesContent: View {
    let viewModel: WatchPrayerTimesModel
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            hero
            list
        }
        .padding(.horizontal, 2)
    }

    private var header: some View {
        Text(viewModel.locationName)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var hero: some View {
        if let upcoming = viewModel.upcoming(at: now) {
            VStack(alignment: .leading, spacing: 1) {
                Text(upcoming.prayer.title.uppercased(with: Locale(identifier: "tr_TR")))
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Palette.accent)

                Text(viewModel.formatted(upcoming.date))
                    .font(.system(size: 34, weight: .medium, design: .rounded))
                    .monospacedDigit()

                // Saatte geri sayım kendi kendine ilerlesin: uygulama arka
                // planda dururken de doğru kalıyor.
                Text(timerInterval: now...upcoming.date, countsDown: true)
                    .font(.system(size: 13))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
            .padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private var list: some View {
        if let day = viewModel.times(for: now) {
            let current = day.current(at: now)
            VStack(spacing: 0) {
                ForEach(day.ordered, id: \.prayer.id) { entry in
                    let isCurrent = entry.prayer == current
                    let isPast = entry.date <= now && !isCurrent
                    HStack {
                        Text(entry.prayer.title)
                            .font(.system(size: 14, weight: isCurrent ? .semibold : .regular))
                        Spacer(minLength: 4)
                        Text(viewModel.formatted(entry.date))
                            .font(.system(size: 14, weight: isCurrent ? .semibold : .regular))
                            .monospacedDigit()
                    }
                    .foregroundStyle(isCurrent ? .primary : (isPast ? .tertiary : .secondary))
                    .padding(.vertical, 6)
                    .overlay(alignment: .leading) {
                        if isCurrent {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Palette.accent)
                                .frame(width: 2, height: 14)
                                .offset(x: -6)
                        }
                    }
                    if entry.prayer != day.ordered.last?.prayer {
                        Divider().opacity(0.4)
                    }
                }
            }
            .accessibilityElement(children: .contain)
        }
    }
}
