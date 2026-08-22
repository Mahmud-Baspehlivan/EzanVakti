import SwiftUI

/// Widget görünümleri — saf SwiftUI, WidgetKit'e bağlı değil. Böylece
/// `Tools/render` ile Xcode olmadan görsel olarak kontrol edilebiliyorlar.
///
/// Geri sayım her yerde `Text(timerInterval:)` ile veriliyor. Uygulamadaki
/// sakin biçim ("1 sa 46 dk") burada kullanılamıyor: zaman çizelgesi yalnızca
/// vakit geçişlerinde girdi ürettiği için durağan bir metin bir dakika içinde
/// yanlış olurdu. Sistem biçimi karşılığında canlı kalıyor.

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter
}()

private func shortTime(_ date: Date) -> String { timeFormatter.string(from: date) }

/// Geçen/kalan oranı — ana ekran widget'larında boşluğu dolduran tek görsel öge.
private struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.14))
                Capsule()
                    .fill(Palette.accent)
                    .frame(width: max(2, geo.size.width * progress))
            }
        }
        .frame(height: 3)
    }
}

/// Konum satırı; paylaşılan konum okunamadığında bunu belirtiyor.
private struct LocationLabel: View {
    let entry: PrayerEntry

    var body: some View {
        HStack(spacing: 3) {
            if entry.isUsingFallbackLocation {
                Image(systemName: "location.slash").font(.system(size: 8))
            }
            Text(entry.isUsingFallbackLocation
                 ? "\(entry.locationName) (varsayılan)"
                 : entry.locationName)
                .lineLimit(1)
        }
        .font(.system(size: 11))
        .foregroundStyle(.white.opacity(entry.isUsingFallbackLocation ? 0.75 : 0.5))
    }
}

// MARK: - Kilit ekranı

/// Kilit ekranı görünümleri renk kullanmıyor: sistem bunları tek renge
/// tonluyor, altın vurgu orada kayboluyor.
struct RectangularWidgetView: View {
    let entry: PrayerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let upcoming = entry.upcoming {
                HStack(spacing: 4) {
                    Image(systemName: upcoming.prayer.symbolName)
                        .font(.system(size: 11))
                    Text(upcoming.prayer.title)
                        .font(.headline)
                    Spacer(minLength: 0)
                    Text(shortTime(upcoming.date))
                        .font(.headline)
                        .monospacedDigit()
                }
                Text(timerInterval: entry.date...upcoming.date, countsDown: true)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                ProgressView(value: entry.progress)
                    .progressViewStyle(.linear)
                    .scaleEffect(y: 0.6, anchor: .center)
            } else {
                Text("Vakit hesaplanamadı").font(.caption)
            }
        }
    }
}

struct CircularWidgetView: View {
    let entry: PrayerEntry

    var body: some View {
        ZStack {
            Circle().stroke(.tertiary, lineWidth: 4)
            Circle()
                .trim(from: 0, to: entry.progress)
                .stroke(.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if let upcoming = entry.upcoming {
                VStack(spacing: -2) {
                    Image(systemName: upcoming.prayer.symbolName)
                        .font(.system(size: 11))
                    Text(shortTime(upcoming.date))
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                }
            }
        }
    }
}

struct InlineWidgetView: View {
    let entry: PrayerEntry

    var body: some View {
        if let upcoming = entry.upcoming {
            Text("\(upcoming.prayer.title) \(shortTime(upcoming.date))")
        } else {
            Text("Ezan Vakti")
        }
    }
}

// MARK: - Ana ekran

struct SmallWidgetView: View {
    let entry: PrayerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LocationLabel(entry: entry)

            Spacer(minLength: 4)

            if let upcoming = entry.upcoming {
                // Uygulamadaki hiyerarşinin aynısı: vakit adı altın etiket,
                // saat kahraman, geri sayım destek.
                SectionLabel(text: upcoming.prayer.title, size: 11, tracking: 1.8)

                Text(shortTime(upcoming.date))
                    .font(.system(size: 34, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                Text(timerInterval: entry.date...upcoming.date, countsDown: true)
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.6))

                Spacer(minLength: 6)
                ProgressBar(progress: entry.progress)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MediumWidgetView: View {
    let entry: PrayerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                LocationLabel(entry: entry)
                Spacer(minLength: 8)
                if let upcoming = entry.upcoming {
                    HStack(spacing: 5) {
                        SectionLabel(text: upcoming.prayer.title, size: 10, tracking: 1.4)
                        Text(timerInterval: entry.date...upcoming.date, countsDown: true)
                            .font(.system(size: 12, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(maxWidth: 62, alignment: .trailing)
                    }
                }
            }

            HStack(spacing: 0) {
                ForEach(entry.slots) { slot in
                    let isNext = slot.prayer == entry.upcoming?.prayer
                    VStack(spacing: 4) {
                        Image(systemName: slot.prayer.symbolName)
                            .font(.system(size: 12))
                        Text(slot.prayer.title)
                            .font(.system(size: 9.5))
                        Text(shortTime(slot.date))
                            .font(.system(size: 13, weight: isNext ? .bold : .regular))
                            .monospacedDigit()
                    }
                    // Sıradaki vakit altın zeminde: uygulamadaki vurgu rengiyle aynı.
                    .foregroundStyle(isNext ? .black.opacity(0.82) : .white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background {
                        if isNext {
                            RoundedRectangle(cornerRadius: 9).fill(Palette.accent)
                        }
                    }
                }
            }

            ProgressBar(progress: entry.progress)
        }
    }
}
