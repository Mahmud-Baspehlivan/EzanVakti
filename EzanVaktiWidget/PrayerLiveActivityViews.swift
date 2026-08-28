import SwiftUI

/// Live Activity görünümleri — ActivityKit'e bağlı değil, `Tools/render` ile
/// Xcode olmadan basılabiliyor.
///
/// Geri sayım ve ilerleme çubuğu `timerInterval` alan sürümlerle kuruluyor:
/// sistem Live Activity'yi yalnızca içerik güncellendiğinde yeniden çiziyor,
/// durağan bir çubuk saatlerce donuk kalırdı. Bu sürümler kendi kendine
/// ilerliyor, güncelleme göndermeye gerek kalmıyor.
///
/// `isStale` vakit girdikten sonra doğru oluyor. O andan itibaren geri sayım
/// göstermek anlamsız — donmuş bir "0:00" bozuk görünüyordu. Bunun yerine
/// vaktin girdiği söyleniyor. Etkinliğin kendisi uygulama açılana kadar
/// duruyor; bitirmek uygulamanın çalışmasını gerektiriyor (bkz. README).

/// Sabit biçimli tarihlerde locale `en_US_POSIX` olmak zorunda: aksi halde
/// kullanıcının "Ayarlar > Genel > Tarih ve Saat > 24 Saat" anahtarı "HH:mm"
/// kalıbını yeniden yorumlatıp "1:46 PM" gibi uzun bir metin ürettirebiliyor.
/// Dinamik Ada'da saatin yeri sabit (`.frame(width: 52)`), uzun biçim kırpılırdı.
/// Saat dilimi `.autoupdatingCurrent`: kullanıcı seyahat ederken vakitler
/// bulunduğu yerin saatiyle yazılsın.
///
/// `DateFormatter` Sendable değil; bu yüzden formatter da onu kullanan yardımcı
/// da `@MainActor`'a bağlı — SwiftUI gövdeleri zaten orada çağırıyor.
@MainActor
private let activityTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .autoupdatingCurrent
    formatter.dateFormat = "HH:mm"
    return formatter
}()

@MainActor
private func hhmm(_ date: Date) -> String { activityTimeFormatter.string(from: date) }

/// Dinamik Ada, kompakt sol: yalnızca hangi vakit olduğu.
struct ActivityCompactLeading: View {
    let content: PrayerActivityContent

    var body: some View {
        Image(systemName: content.prayer.symbolName)
            .foregroundStyle(Palette.accent)
    }
}

/// Dinamik Ada, kompakt sağ: bakışta sorulan tek soru — ne kadar kaldı.
struct ActivityCompactTrailing: View {
    let content: PrayerActivityContent
    var isStale = false

    var body: some View {
        Group {
            if isStale {
                // Vakit girdi: saatin kendisi donmuş bir sayaçtan anlamlı.
                Text(hhmm(content.prayerTime))
            } else {
                Text(timerInterval: content.previousTime...content.prayerTime, countsDown: true)
            }
        }
        .font(.system(size: 13, weight: .medium))
        .monospacedDigit()
        .foregroundStyle(Palette.accent)
        .frame(width: 52)
    }
}

/// İki etkinlik aynı anda varken ada minik daireye iniyor.
struct ActivityMinimal: View {
    let content: PrayerActivityContent

    var body: some View {
        Image(systemName: content.prayer.symbolName)
            .foregroundStyle(Palette.accent)
    }
}

/// Uzun basınca açılan geniş hal.
struct ActivityExpandedLeading: View {
    let content: PrayerActivityContent

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: content.prayer.symbolName)
                .font(.system(size: 15))
                .foregroundStyle(Palette.accent)
            Text(content.prayer.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.leading, 4)
    }
}

struct ActivityExpandedTrailing: View {
    let content: PrayerActivityContent

    var body: some View {
        Text(hhmm(content.prayerTime))
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.trailing, 4)
    }
}

struct ActivityExpandedBottom: View {
    let content: PrayerActivityContent
    var isStale = false

    var body: some View {
        if isStale {
            HStack {
                Text("\(content.prayer.title) vakti girdi")
                    .foregroundStyle(.white.opacity(0.75))
                Spacer(minLength: 8)
                Text(content.locationName)
                    .foregroundStyle(.white.opacity(0.45))
            }
            .font(.system(size: 12))
            .padding(.horizontal, 4)
        } else {
            expanded
        }
    }

    private var expanded: some View {
        VStack(spacing: 6) {
            ProgressView(timerInterval: content.previousTime...content.prayerTime,
                         countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                .progressViewStyle(.linear)
                .tint(Palette.accent)

            HStack {
                Text(content.locationName)
                    .foregroundStyle(.white.opacity(0.45))
                Spacer(minLength: 8)
                Text(timerInterval: content.previousTime...content.prayerTime, countsDown: true)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: 74, alignment: .trailing)
            }
            .font(.system(size: 12))
        }
        .padding(.horizontal, 4)
    }
}

/// Kilit ekranında ve Dinamik Ada'sı olmayan cihazlarda görünen kart.
struct ActivityLockScreenView: View {
    let content: PrayerActivityContent
    var isStale = false

    var body: some View {
        if isStale { stale } else { live }
    }

    /// Vakit girdikten sonra: geri sayım ve ilerleme kaldırılıyor.
    private var stale: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: content.prayer.title, size: 11, tracking: 1.8)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(hhmm(content.prayerTime))
                    .font(.system(size: 30, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text("vakti girdi")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer(minLength: 0)
            }
            Text(content.locationName)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(16)
    }

    private var live: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(text: content.prayer.title, size: 11, tracking: 1.8)
                Spacer(minLength: 8)
                Text(content.locationName)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(hhmm(content.prayerTime))
                    .font(.system(size: 34, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Text(timerInterval: content.previousTime...content.prayerTime, countsDown: true)
                    .font(.system(size: 15, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: 92, alignment: .trailing)
            }

            ProgressView(timerInterval: content.previousTime...content.prayerTime,
                         countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                .progressViewStyle(.linear)
                .tint(Palette.accent)
        }
        .padding(16)
    }
}
