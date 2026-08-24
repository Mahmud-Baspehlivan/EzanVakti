import SwiftUI

/// Saatteki ana ekran.
///
/// Telefon uygulamasının küçültülmüş hâli değil: en küçük desteklenen ekranda
/// (40 mm, 162×197 pt) durum çubuğu düşünce ~175 pt yer kalıyor. Altı vakit alt
/// alta oraya sığmadığı için liste iki sütuna katlandı — böylece gün tamamı
/// kaydırma gerektirmeden tek bakışta görünüyor.
struct WatchPrayerTimesView: View {
    let viewModel: WatchPrayerTimesModel
    let now: Date

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        GeometryReader { geo in
            let content = WatchPrayerTimesContent(
                viewModel: viewModel, now: now, height: geo.size.height)
            // Normal puntolarda kaydırma yok, içerik ekrana sığıyor.
            // Erişilebilirlik puntolarında sığması mümkün değil, orada kaydırılsın.
            if typeSize.isAccessibilitySize {
                ScrollView { content }
            } else {
                content
            }
        }
    }
}

/// Eldeki yüksekliğe göre ölçüler.
///
/// Tek bir sabit set ya 40 mm'den taşıyordu ya da 45 mm'nin altında ölü bir
/// bant bırakıyordu. Karar genişliğe değil yüksekliğe bakıyor: ekran boyu ve
/// durum çubuğu payı modelden modele değiştiği için genişlik ancak dolaylı bir
/// gösterge, `GeometryReader` ise gerçekten kalan yeri söylüyor. Eşikler her
/// kademenin ölçülmüş boyunun (kompakt 154, orta 174, ferah 204 pt) üstünde.
struct WatchMetrics {
    let headerFont: CGFloat
    let heroTime: CGFloat
    let heroBottom: CGFloat
    let rowFont: CGFloat
    let rowPadV: CGFloat
    let rowSpacing: CGFloat

    static func forHeight(_ height: CGFloat) -> WatchMetrics {
        if height >= 210 {
            return .init(headerFont: 12, heroTime: 38, heroBottom: 12,
                         rowFont: 15, rowPadV: 8, rowSpacing: 5)
        }
        if height >= 180 {
            return .init(headerFont: 12, heroTime: 34, heroBottom: 10,
                         rowFont: 13, rowPadV: 6, rowSpacing: 4)
        }
        return .init(headerFont: 11, heroTime: 30, heroBottom: 8,
                     rowFont: 12, rowPadV: 5, rowSpacing: 3)
    }
}

/// Kaydırma kabuğundan ayrı: `ImageRenderer` ScrollView içeriğini basmıyor,
/// bu haliyle saat ekranı Xcode olmadan denetlenebiliyor.
struct WatchPrayerTimesContent: View {
    let viewModel: WatchPrayerTimesModel
    let now: Date
    let height: CGFloat

    private var metrics: WatchMetrics { .forHeight(height) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            hero
            grid
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
    }

    private var header: some View {
        Text(viewModel.locationName)
            .font(.system(size: metrics.headerFont))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var hero: some View {
        if let upcoming = viewModel.upcoming(at: now) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(upcoming.prayer.title.uppercased(with: Locale(identifier: "tr_TR")))
                        .font(.system(size: metrics.headerFont - 1, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(Palette.accent)
                        .lineLimit(1)

                    Spacer(minLength: 2)

                    // Saatte geri sayım kendi kendine ilerlesin: uygulama arka
                    // planda dururken de doğru kalıyor.
                    Text(timerInterval: now...upcoming.date, countsDown: true)
                        .font(.system(size: metrics.headerFont))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(viewModel.formatted(upcoming.date))
                    .font(.system(size: metrics.heroTime, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
            .padding(.bottom, metrics.heroBottom)
        }
    }

    @ViewBuilder
    private var grid: some View {
        if let day = viewModel.times(for: now) {
            let current = day.current(at: now)
            let rows = stride(from: 0, to: day.ordered.count, by: 2).map {
                Array(day.ordered[$0 ..< min($0 + 2, day.ordered.count)])
            }
            VStack(spacing: metrics.rowSpacing) {
                ForEach(rows.indices, id: \.self) { row in
                    HStack(spacing: metrics.rowSpacing) {
                        ForEach(rows[row], id: \.prayer.id) { entry in
                            cell(entry, current: current)
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    private func cell(_ entry: (prayer: Prayer, date: Date), current: Prayer?) -> some View {
        let isCurrent = entry.prayer == current
        let isPast = entry.date <= now && !isCurrent
        let weight: Font.Weight = isCurrent ? .semibold : .regular
        // Saat sabit, isim esnek. Aralarına Spacer koyunca isim yeri Spacer'la
        // paylaşmak zorunda kalıp "Akşa..." diye kırpılıyordu; artan genişliği
        // doğrudan isme vermek 40 mm'de de tam yazıyor.
        return HStack(spacing: 3) {
            Text(entry.prayer.title)
                .font(.system(size: metrics.rowFont, weight: weight))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
            // Saat asla kırılmasın: dar ekranda "04:4 / 2" diye ikiye bölünüp
            // satır yüksekliğini ikiye katlıyordu.
            Text(viewModel.formatted(entry.date))
                .font(.system(size: metrics.rowFont, weight: weight))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(isCurrent ? .primary : (isPast ? .tertiary : .secondary))
        .padding(.vertical, metrics.rowPadV)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Palette.accent.opacity(isCurrent ? 0.20 : 0.07))
        )
        .accessibilityElement(children: .combine)
    }
}
