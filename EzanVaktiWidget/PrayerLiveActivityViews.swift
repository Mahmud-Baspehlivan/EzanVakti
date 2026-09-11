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
/// Dinamik Ada'da saatin yeri sabit (`.frame(width: 56)`), uzun biçim kırpılırdı.
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
                Text(timerInterval: content.windowStart...content.prayerTime, countsDown: true)
            }
        }
        .font(.system(size: 13, weight: .medium))
        .monospacedDigit()
        .lineLimit(1)
        // Yer sabit ama metnin uzunlugu degil: pencere bir saatin altindayken
        // "45:12", ustunde "2:59:59". Yedi haneli hali 13 puntoda 52 pt'ye
        // sigmiyor ve kirpiliyordu; olcek etkeni ada'nin yerini buyutmeden
        // uzun bicimi de gosteriyor.
        .minimumScaleFactor(0.75)
        .foregroundStyle(Palette.accent)
        .frame(width: 56)
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
            ProgressView(timerInterval: content.windowStart...content.prayerTime,
                         countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                .progressViewStyle(.linear)
                .tint(Palette.accent)

            HStack {
                Text(content.locationName)
                    .foregroundStyle(.white.opacity(0.45))
                Spacer(minLength: 8)
                Text(timerInterval: content.windowStart...content.prayerTime, countsDown: true)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: 82, alignment: .trailing)
            }
            .font(.system(size: 12))
        }
        .padding(.horizontal, 4)
    }
}

/// Kilit ekranında ve Dinamik Ada'sı olmayan cihazlarda görünen kart.
///
/// Bakışta okunan tek şey kalan süre, o yüzden kartın kahramanı o. Önceki
/// sürümde 34 puntoyla yazılan şey vaktin saatiydi ve kalan süre onun yanında
/// 15 puntoluk soluk bir ikinci saat olarak duruyordu: kilit ekranında iki
/// rakam grubu yan yana, hangisinin ne olduğu belirsiz. Şimdi geri sayım
/// büyük ve "kaldı" ile etiketli, vaktin saati sağda ikincil.
///
/// Vakit ikonu da eklendi: Dinamik Ada'nın her sunumunda o ikon var, kartta
/// yoktu — aynı etkinliğin iki yüzü birbirini tutmuyordu.
struct ActivityLockScreenView: View {
    let content: PrayerActivityContent
    var isStale = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if isStale { stale } else { live }
        }
        // Yatayda 16, dikeyde 14: sistem kartın çevresine kendi kenar boşluğunu
        // koyuyor, dört yanda 16 kartı gereksiz uzatıyordu.
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    /// Üst satır iki durumda da aynı: hangi vakit, nerede.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: content.prayer.symbolName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.accent)
            SectionLabel(text: content.prayer.title, size: 11, tracking: 1.8)
            Spacer(minLength: 8)
            Text(content.locationName)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
        }
    }

    /// Vakit girdikten sonra: geri sayım ve ilerleme kaldırılıyor.
    private var stale: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(hhmm(content.prayerTime))
                .font(.system(size: 30, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text("vakti girdi")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
            Spacer(minLength: 0)
        }
    }

    private var live: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .lastTextBaseline, spacing: 7) {
                Text(timerInterval: content.windowStart...content.prayerTime, countsDown: true)
                    .font(.system(size: 34, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    // Metnin genişliği pencereyle değişiyor ("58:12" ile
                    // "2:59:59" arasında ~%40): sabit bir yer ayırmak yerine
                    // gerekirse küçülüyor, böylece saat de sağda kalabiliyor.
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.white)
                Text("kaldı")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer(minLength: 8)
                Text(hhmm(content.prayerTime))
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.7))
            }

            ProgressView(timerInterval: content.windowStart...content.prayerTime,
                         countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                .progressViewStyle(.linear)
                .tint(Palette.accent)
        }
    }
}
