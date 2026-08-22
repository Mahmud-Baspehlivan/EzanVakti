import SwiftUI

/// Widget görünümleri — saf SwiftUI, WidgetKit'e bağlı değil. Böylece
/// `Tools/render` ile Xcode olmadan görsel olarak kontrol edilebiliyorlar.

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter
}()

private func shortTime(_ date: Date) -> String { timeFormatter.string(from: date) }

/// Konum satırı. Paylaşılan konum okunamadığında varsayılan şehir gösteriliyor;
/// bunu belirtmezsek widget sessizce yanlış şehrin vakitlerini gösterir.
private struct LocationLabel: View {
    let entry: PrayerEntry

    var body: some View {
        HStack(spacing: 3) {
            if entry.isUsingFallbackLocation {
                Image(systemName: "location.slash")
                    .font(.system(size: 8))
            }
            Text(entry.isUsingFallbackLocation
                 ? "\(entry.locationName) (varsayılan)"
                 : entry.locationName)
                .lineLimit(1)
        }
        .font(.caption2)
        .foregroundStyle(.white.opacity(entry.isUsingFallbackLocation ? 0.75 : 0.55))
    }
}

/// Kilit ekranı — dikdörtgen
struct RectangularWidgetView: View {
    let entry: PrayerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
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
                // Geri sayım kendi kendine ilerliyor; bunun için yeni zaman
                // çizelgesi girdisi üretmek gerekmiyor.
                Text(timerInterval: entry.date...upcoming.date, countsDown: true)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                Text("Vakit hesaplanamadı").font(.caption)
            }
        }
    }
}

/// Kilit ekranı — dairesel
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
                VStack(spacing: -1) {
                    Image(systemName: upcoming.prayer.symbolName)
                        .font(.system(size: 10))
                    Text(shortTime(upcoming.date))
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                }
            }
        }
    }
}

/// Kilit ekranı — satır içi
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

/// Ana ekran — küçük
struct SmallWidgetView: View {
    let entry: PrayerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LocationLabel(entry: entry)

            Spacer(minLength: 6)

            if let upcoming = entry.upcoming {
                Text(upcoming.prayer.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text(shortTime(upcoming.date))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(timerInterval: entry.date...upcoming.date, countsDown: true)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(2)
    }
}

/// Ana ekran — orta
struct MediumWidgetView: View {
    let entry: PrayerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                LocationLabel(entry: entry)
                Spacer()
                if let upcoming = entry.upcoming {
                    Text(timerInterval: entry.date...upcoming.date, countsDown: true)
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(maxWidth: 70, alignment: .trailing)
                }
            }

            HStack(spacing: 0) {
                ForEach(entry.slots) { slot in
                    let isNext = slot.prayer == entry.upcoming?.prayer
                    VStack(spacing: 5) {
                        Image(systemName: slot.prayer.symbolName)
                            .font(.system(size: 13))
                        Text(slot.prayer.title)
                            .font(.system(size: 10))
                        Text(shortTime(slot.date))
                            .font(.system(size: 13, weight: isNext ? .bold : .regular))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white.opacity(isNext ? 1 : 0.55))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background {
                        if isNext {
                            RoundedRectangle(cornerRadius: 9).fill(.white.opacity(0.16))
                        }
                    }
                }
            }
        }
    }
}
