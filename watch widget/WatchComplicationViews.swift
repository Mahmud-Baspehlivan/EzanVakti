import SwiftUI
import WidgetKit

/// Kadran komplikasyonları. Saf SwiftUI — `Tools/render` ile denetlenebiliyor.
///
/// Komplikasyonlar sistem tarafından tek renge tonlanıyor, o yüzden altın vurgu
/// kullanılmıyor. Geri sayım ve halka `timerInterval` alan sürümlerle kuruluyor:
/// zaman çizelgesi yalnızca vakit geçişlerinde girdi ürettiği için durağan bir
/// gösterge saatlerce donuk kalırdı.
///
/// Geri düşüş konumu (App Group boş ya da konum izni yok) yalnızca dikdörtgen
/// ve tek satır ailelerinde belirtiliyor. Tonlama yüzünden uyarı renkle
/// verilemiyor, geriye yer kaplayan bir simge kalıyor; daire ve köşede o yeri
/// vaktin simgesi tutuyor ve onu harcamak hangi vakte bakıldığını gizlerdi.
/// Yanlış şehrin vaktini sessizce göstermek kötü, ama bu iki dar ailede vaktin
/// kimliğini feda etmek daha kötü — uyarıyı geniş aileler ve uygulama veriyor.

/// `en_US_POSIX`: sabit "HH:mm" biçimi ancak yerelden bağımsız bir takvimle
/// güvenilir, aksi hâlde "24 Saat" anahtarını kapatan kullanıcıda sistem
/// biçimi AM/PM'e çeviriyor. Saat dilimi `.autoupdatingCurrent`, çünkü
/// biçimlendirici uzantı süreci boyunca yaşıyor ve dilim değişimini kaçırmamalı.
///
/// `@MainActor`: `DateFormatter` Sendable değil, dosya kapsamlı bir kopya Swift
/// 6 kipinde doğrudan hata. Bu hedefte varsayılan yalıtım zaten MainActor ve tek
/// çağrı yeri görünüm gövdeleri, yani ana aktör — yalıtımı açıkça yazmak sorunu
/// `nonisolated(unsafe)` gibi gizlemek yerine gerçekten çözüyor.
@MainActor
private let complicationFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .autoupdatingCurrent
    formatter.dateFormat = "HH:mm"
    return formatter
}()

@MainActor
private func hhmm(_ date: Date) -> String { complicationFormatter.string(from: date) }

/// Kadranda küçük daire: halka geçen oranı, ortada vaktin saati.
///
/// Ortada geri sayım denendi ve geri alındı: çemberin iç alanı ~30 pt, `6:50:10`
/// 11 pt'de ~50 pt istiyor. Küçültme çarpanıyla bile taşıyor ve okunmuyor.
/// "Ne kadar kaldı"yı zaten halka söylüyor; içeriye "ne zaman" yazmak ikisini
/// bölüştürüyor, aynı bilgiyi iki kez sıkıştırmaya çalışmıyor.
struct WatchCircularComplication: View {
    let entry: PrayerEntry

    var body: some View {
        if let upcoming = entry.upcoming, let previous = entry.previous {
            ZStack {
                ProgressView(timerInterval: previous...upcoming.date, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.circular)

                VStack(spacing: -1) {
                    Image(systemName: upcoming.prayer.symbolName)
                        .font(.system(size: 9))
                    Text(hhmm(upcoming.date))
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                }
            }
        } else {
            Image(systemName: "moon.stars")
        }
    }
}

/// Kadran köşesi: kalan süre kavisli kenarda, vakit simgesi içeride.
///
/// Kalan süre `widgetLabel` ile kenara yazılıyor, köşenin iç alanına değil:
/// orası dört-beş karakter alıyor. Kavisli kenarda yer var; hangi vakit olduğunu
/// da içerideki simge söylüyor.
///
/// Biçim `.relative`: ham geri sayım ("10:41:34") saniyesi hiç işe yaramayan üç
/// haneli bir sayı yığını, `.relative` ise sistemin diliyle "10 sa. 41 dk."
/// yazıyor. İkisi de kendi kendine ilerliyor, yani çizelgeye girdi eklemiyor —
/// durağan metnin yasak olduğu yerde tek fark okunurluk.
struct WatchCornerComplication: View {
    let entry: PrayerEntry

    var body: some View {
        if let upcoming = entry.upcoming {
            symbol(upcoming.prayer.symbolName)
                .widgetLabel {
                    Text(upcoming.date, style: .relative)
                }
        } else {
            symbol("moon.stars")
        }
    }

    /// Köşenin iç alanını dolduran, ortalanmış simge.
    ///
    /// `frame(maxWidth:maxHeight:)` şart: simge yalnız kendi asıl boyutunda
    /// kalınca yerleşimi kapsayıcının varsayılan hizasına kalıyor ve köşede
    /// kayık duruyor. Alanı açıkça kaplayıp ortalayınca sonuç her kadranda aynı.
    ///
    /// 16 pt'den 20 pt'ye çıktı: köşenin iç alanı ~30 pt ve simge tek başına
    /// hangi vakit olduğunu söyleyen tek işaret — kavisli kenarda yalnız süre
    /// yazıyor. O kadar iş yüklenen bir simgenin alanın yarısında kalması az.
    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 20, weight: .medium))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Dikdörtgen: en çok bilgi sığan hâl.
///
/// Üç satır sabit aralıkla üst üste duruyor ve blok yuvada dikey olarak
/// ortalanıyor. Nefes payı böylece **yuvaya orantılı** oluyor: geniş kadranda
/// alta ve üste birkaç punto boşluk düşüyor, dar kadranda kendiliğinden
/// sıfıra iniyor. Sabit bir dolgu yazsaydık dar kadranda tam da sığması
/// gereken yeri çalardı.
///
/// Satırları `Spacer` ile kenarlara yaslamak da denendi: boşluk kenardan
/// gidiyor ama bu sefer içerik yuvanın kenarına yapışıyor ve komplikasyon
/// sıkışık görünüyor. Boşluğu yok etmek değil, ölçüsünü yuvaya bırakmak doğru.
struct WatchRectangularComplication: View {
    let entry: PrayerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let upcoming = entry.upcoming, let previous = entry.previous {
                HStack(spacing: 4) {
                    // Simge metnin İÇİNE gömülü, yanına konmuş ayrı bir görünüm
                    // değil. `HStack` simgeyi kendi çerçevesine göre ortalıyor;
                    // metin çerçevesi ise alt çıkıntı payı taşıdığı için simge
                    // görsel merkezin üstünde kalıyor, satır kayık duruyordu.
                    // Metne gömülen simge taban çizgisine kendiliğinden oturuyor.
                    //
                    // `imageScale(.large)`: SF Symbol aynı puntoda harflerden
                    // ince kalıyor; "moon.stars" gibi ayrıntılı bir simge 11
                    // pt'de leke gibi görünüyordu, bir kademe büyüyünce adın
                    // görsel ağırlığına yetişiyor.
                    //
                    // Vaktin adı birincil, saati ikincil: satırın taşıdığı asıl
                    // bilgi hangi vakit olduğu, saat onu doğrulayan ayrıntı.
                    // Üçü de aynı tonda dururken satır tek bir gri şerit gibi
                    // okunuyordu.
                    Text("\(Image(systemName: upcoming.prayer.symbolName))  \(upcoming.prayer.title)")
                        .font(.system(size: 11, weight: .medium))
                        .imageScale(.large)
                    Spacer(minLength: 0)
                    Text(hhmm(upcoming.date))
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    if entry.isUsingFallbackLocation {
                        Image(systemName: "location.slash")
                            .font(.system(size: 9, weight: .medium))
                            .accessibilityLabel("Varsayılan konum kullanılıyor")
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    // `.relative`: "6 sa. 50 dk." — birimler süre olduğunu
                    // söylediği için "kaldı" ayrıca yazılmıyor, üstelik dar
                    // yuvada kırpılacak ilk şey o olurdu. Üstteki satır hangi
                    // vakit ve saat kaç zaten yazıyor.
                    Text(upcoming.date, style: .relative)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                ProgressView(timerInterval: previous...upcoming.date, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.linear)
            } else {
                Text("Vakit hesaplanamadı").font(.system(size: 12))
            }
        }
        // Dikey sistem payı burada değil, `contentMarginsDisabled()` ile
        // kapatılıyor; yatay payı `WatchComplicationEntryView` geri veriyor.
        //
        // Denenip vazgeçilen: `.padding(.vertical, -15)`. Negatif pay payı
        // kaldırmıyor, içeriği yuvadan taşırıyor ve WidgetKit taşanı kırpıyor —
        // 48 pt yükseklikte üst satır ikiye bölünüyordu, 56 pt'de bölünmüyordu.
        // Yuva saat modeline göre değiştiği için sabit bir sayı her cihazda
        // doğru olamaz.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

/// Kadranın üst satırı: tek satır metin.
struct WatchInlineComplication: View {
    let entry: PrayerEntry

    var body: some View {
        if let upcoming = entry.upcoming {
            // Tek satır aile sondan kırpılıyor; "kaldı" burada da düşürülüyor
            // ki kırpma sınırına en son gelinsin.
            let countdown = Text(upcoming.date, style: .relative)
            let line = Text("\(upcoming.prayer.title) · \(countdown)")
            // Çizili konum simgesi metnin BAŞINA giriyor: tek satır aile
            // kadranın genişliğine göre sondan kırpılıyor, sona eklenen bir
            // uyarı ilk kaybolan şey olurdu.
            if entry.isUsingFallbackLocation {
                Text("\(Image(systemName: "location.slash")) \(line)")
            } else {
                line
            }
        } else {
            Text("Ezan Vakti")
        }
    }
}
