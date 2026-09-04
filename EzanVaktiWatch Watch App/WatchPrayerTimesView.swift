import SwiftUI

/// Saatteki ana ekran.
///
/// Telefon uygulamasının küçültülmüş hâli değil: en küçük desteklenen ekranda
/// (40 mm, 162×197 pt) durum çubuğu düşünce ~175 pt yer kalıyor. Altı vakit alt
/// alta oraya sığmadığı için liste iki sütuna katlandı — böylece gün tamamı
/// kaydırma gerektirmeden tek bakışta görünüyor.
struct WatchPrayerTimesView: View {
    let viewModel: WatchPrayerTimesModel
    let tracking: WatchTrackingStore
    let now: Date

    /// Seçim sayfası kabukta duruyor: `sheet` kaydırma alanının içinden
    /// sunulursa erişilebilirlik puntolarında sayfayı kaydırma kapsıyor.
    @State private var picking: Prayer?

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        GeometryReader { geo in
            let content = WatchPrayerTimesContent(
                viewModel: viewModel, now: now, height: geo.size.height,
                tracking: tracking, onSelect: { picking = $0 })
            // Normal puntolarda kaydırma yok, içerik ekrana sığıyor.
            // Erişilebilirlik puntolarında sığması mümkün değil, orada kaydırılsın.
            if typeSize.isAccessibilitySize {
                ScrollView { content }
            } else {
                content
            }
        }
        .sheet(item: $picking) { prayer in
            WatchStatusPicker(
                prayer: prayer,
                time: viewModel.times(for: now).map { viewModel.formatted($0[prayer]) } ?? "",
                current: tracking.entry(for: prayer, on: now).status,
                onSelect: { status in
                    tracking.mark(status, for: prayer, on: now)
                    picking = nil
                }
            )
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
    /// İşaretleme isteğe bağlı: `ImageRenderer` ile basılırken `WCSession`
    /// kurmaya gerek kalmasın, ekran tek satırda kurulabilsin.
    var tracking: WatchTrackingStore?
    var onSelect: (Prayer) -> Void = { _ in }

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
        // Varsayılan şehirle çalışırken bunu söylüyoruz: telefonda ve widget'ta
        // olduğu gibi, yanlış şehrin vakitlerini sessizce doğruymuş gibi
        // göstermiyoruz. Ekran metin taşıyamayacak kadar dar; uyarıyı simge ile
        // turuncu ton taşıyor, VoiceOver için karşılığı aşağıda yazılı.
        HStack(spacing: 3) {
            if viewModel.isUsingFallbackLocation {
                Image(systemName: "location.slash")
                    .font(.system(size: metrics.headerFont - 1))
            }
            Text(viewModel.locationName)
                .font(.system(size: metrics.headerFont))
                .lineLimit(1)
        }
        .foregroundStyle(viewModel.isUsingFallbackLocation ? Color.orange : Color.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.isUsingFallbackLocation
                            ? "Varsayılan şehir: \(viewModel.locationName)"
                            : "Konum: \(viewModel.locationName)")
    }

    @ViewBuilder
    private var hero: some View {
        if let upcoming = viewModel.upcoming(at: now) {
            // Geri sayımın alt ucu "şu an" değil, içinde bulunulan vaktin anı:
            // aralık her karede yeniden kurulmasın diye. Vakit hesaplanamazsa
            // şu ana düşüyoruz — sayaç yine doğru, sadece aralık oynak.
            let start = viewModel.previousBoundary(at: now) ?? now
            VStack(alignment: .leading, spacing: 0) {
                // Vaktin saati adına **bitişik**: "İKİNDİ 16:56" tek bir bilgi
                // olarak okunuyor. Aralarına Spacer koyup iki kenara itmek bu
                // bağı bozuyordu — sağ kenarda tek başına duran "16:56" neyin
                // saati olduğunu söylemiyor, ekrandaki üçüncü etiketsiz sayı
                // oluyordu.
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(upcoming.prayer.title.uppercased(with: Locale(identifier: "tr_TR")))
                        .font(.system(size: metrics.headerFont - 1, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(Palette.accent)
                        .lineLimit(1)

                    Text(viewModel.formatted(upcoming.date))
                        .font(.system(size: metrics.headerFont + 1, weight: .semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Spacer(minLength: 0)
                }

                // Bir saatin üstünde sözcüklü biçim, son 10 dakikada saniyeli
                // sayaç. Gerekçe `remainingReadout`'ta yazılı.
                if let readout = viewModel.remainingReadout(at: now) {
                    countdownRow {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            ForEach(readout.parts) { part in
                                HStack(alignment: .firstTextBaseline, spacing: 1) {
                                    Text(part.value)
                                        .font(.system(size: metrics.heroTime, weight: .medium,
                                                      design: .rounded))
                                        .monospacedDigit()
                                    Text(part.unit)
                                        .font(.system(size: metrics.headerFont + 1, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    }
                    // Parçalara bölünmüş metni VoiceOver "6 sa 21 dk" diye
                    // okuyor; kısaltmalar ekran için, ses için değil.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(readout.spoken) kaldı")
                } else {
                    // Son 10 dakikada sayaç sistemin kendi metni: uygulama arka
                    // planda dururken de kendi kendine ilerliyor.
                    countdownRow {
                        Text(timerInterval: start...upcoming.date, countsDown: true)
                            .font(.system(size: metrics.heroTime, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
            .padding(.bottom, metrics.heroBottom)
        }
    }

    /// Geri sayım satırı: biçim hangisi olursa olsun yanında "kaldı" duruyor.
    ///
    /// Telefonda da geri sayımın yanında bu sözcük var. Birim ("dk") ne kadar
    /// olduğunu söylüyor, "kaldı" ise geçen mi kalan mı olduğunu — ikisi ayrı
    /// soru, ikisi de bir satır yer tutmuyor.
    private func countdownRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            content()
            Text("kaldı")
                .font(.system(size: metrics.headerFont))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 0)
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
                            cell(entry, current: current, times: day)
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    /// Güneş bir namaz vakti değil; işaretlenecek bir şey yok, dokunulmuyor da.
    /// Vakti girmemiş namaz da dokunulmuyor — kural `PrayerMarking`'te ve
    /// telefonla ortak, iki yerde ayrı yazılırsa bir gün ayrışırlar.
    @ViewBuilder
    private func cell(_ entry: (prayer: Prayer, date: Date), current: Prayer?,
                      times: DailyPrayerTimes) -> some View {
        if let tracking, entry.prayer.isPrayer,
           PrayerMarking.isMarkable(entry.prayer, on: now, times: times,
                                    now: now, calendar: tracking.calendar) {
            let marked = tracking.entry(for: entry.prayer, on: now)
            Button { onSelect(entry.prayer) } label: {
                cellBody(entry, current: current, marked: marked)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Durumu seçmek için dokun")
        } else {
            cellBody(entry, current: current, marked: (.unmarked, false))
        }
    }

    private func cellBody(_ entry: (prayer: Prayer, date: Date), current: Prayer?,
                          marked: (status: PrayerStatus, isPending: Bool)) -> some View {
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
        // Durum kenarlıkta duruyor, hücrenin içinde değil: 40 mm'de ada + saat
        // zaten genişliği tüketiyor, araya bir simge sıkıştırmak adı kırpardı.
        // `strokeBorder` içeri çiziyor, düzen bir nokta bile kaymıyor.
        // Kesikli kenarlık "telefona henüz ulaşmadı" demek.
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(marked.status.tint, style: StrokeStyle(
                    lineWidth: 1.5, dash: marked.isPending ? [2.5, 2.5] : []))
                .opacity(marked.status == .unmarked ? 0 : 1)
        )
        // Renk tek başına durumu anlatmıyor (kenarlık küçük, renk körlüğü var);
        // VoiceOver için durum açıkça yazılıyor.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cellAccessibilityLabel(entry, isCurrent: isCurrent,
                                                   isPast: isPast, marked: marked))
    }

    private func cellAccessibilityLabel(
        _ entry: (prayer: Prayer, date: Date), isCurrent: Bool, isPast: Bool,
        marked: (status: PrayerStatus, isPending: Bool)
    ) -> String {
        var parts = ["\(entry.prayer.title) \(viewModel.formatted(entry.date))"]
        if isCurrent { parts.append("şu anki vakit") }
        else if isPast { parts.append("geçti") }
        if marked.status != .unmarked {
            parts.append(marked.isPending ? "\(marked.status.title), gönderiliyor" : marked.status.title)
        }
        return parts.joined(separator: ", ")
    }
}
