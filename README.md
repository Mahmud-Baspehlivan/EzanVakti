# Ezan Vakti

iOS için namaz vakitleri uygulaması. Vakitler cihazda hesaplanır — ağ bağımlılığı ve
sunucu yok, uygulama tamamen çevrimdışı çalışır.

## Yapı

```
EzanVakti/
  Core/                     hesaplama çekirdeği (Foundation dışı bağımlılık yok)
    SolarMath.swift          güneş konumu, zaman denklemi, Jülyen gün
    PrayerTimesCalculator.swift
    PrayerCalculationParameters.swift
    Prayer.swift
  Services/
    LocationProvider.swift
    PrayerNotificationScheduler.swift
  Core/Qibla.swift          kıble yönü + güneş konumu + kıble saati
  Features/RootView.swift   sekmeler (Vakitler / Kıble)
  Features/PrayerTimes/     ekran + view model
  Features/Qibla/           pusula + kıble saati
  Features/Imsakiye/        aylık vakit çizelgesi
  Features/NearbyMosques/   yakındaki camiler (liste + harita)
  Features/Settings/        bildirim ayarları
Tools/check/targets.sh      her hedefi kendi dosya kümesiyle derler
Tools/calibrate/            temkin kalibrasyonu (15 ile karşı ölçüm)
Tools/mosque-extract/       Overpass karolarını paketlenecek cami dosyasına çevirir
Tools/icon/main.swift       uygulama ikonu adaylarını 1024px opak PNG olarak üretir
Tools/tests/main.swift      takip/kaza mağazasının birim testleri
Tools/validate/main.swift   çekirdeği CSV'ye döken doğrulama koşucusu
Tools/render/main.swift     SwiftUI görünümlerini PNG'ye basar (Xcode'suz görsel kontrol)
Tools/make-sound.sh         bildirim sesi dönüştürücü
```

`Tools/` bilerek uygulama klasörünün dışında: hedef, `EzanVakti/` klasörünü
dosya sistemiyle senkronize ettiği için içine konsa `main.swift` `@main` ile çakışırdı.

## Hesaplama yöntemi

Diyanet yöntemi: sabah 18°, yatsı 17°, Şâfiî ikindi (gölge çarpanı 1).

Diyanet yayınladığı takvimde astronomik vakte **temkin** payı ekler. `.astronomical`
preset'i çıplak astronomik değeri verir, `.diyanet` preset'i temkinli değeri.

## Doğrulama

`Tools/validate` İstanbul / Ağustos 2026 için hesaplıyor, gerçek Diyanet takvimiyle
karşılaştırılıyor (17 gün örtüşen veri):

| Vakit | `.astronomical` sapma | `.diyanet` sapma | Tam isabet |
|---|---|---|---|
| İmsak | −1..0 dk | −1..0 dk | 10/17 |
| Güneş | +6..+7 dk | 0..+1 dk | 14/17 |
| Öğle | −6..−5 dk | 0..+1 dk | 11/17 |
| İkindi | −5..−4 dk | 0 dk | 17/17 |
| Akşam | −9..−8 dk | 0..+1 dk | 11/17 |
| Yatsı | −2..−1 dk | 0 dk | 17/17 |

Çıplak hesabın ürettiği doğuş/batış, Diyanet'in kendi astronomik alanlarına
(`GunesDogus`/`GunesBatis`) 1-2 dk içinde oturuyor — yani sapmanın kaynağı
astronomi değil, temkin.

### Ülke geneli doğruluk

Temkin değerleri **15 ilin** gerçek Diyanet takvimine karşı ölçülüp medyanı
alınarak türetildi (Edirne, Hakkari, Sinop, Antalya, Erzurum dahil — uçlardan
seçildi). Sonuç:

| | |
|---|---|
| En kötü sapma (tüm ülke) | **2 dk** |
| Ortalama sapma | 0.56 dk |
| 1 dk içinde kalan karşılaştırma | %92 |

Şaşırtıcı bulgu: gereken düzeltme iller arasında 2-4 dk'dan fazla değişmiyor,
yani tek küme değer ülke genelinde yeterli. Önceki "İstanbul'a kalibre, başka
illerde sapar" uyarısı ölçümle çürüdü.

Kalan 2 dk'lık uçlar (Hakkari, Samsun, Sinop, Van) temkinden değil koordinat
farkından: Diyanet her ilçe için kendi referans noktasını kullanıyor ve
yayınlamıyor. Hesaplamaya dayalı yaklaşımda pratik taban bu.

Yöntem ve yeniden ölçüm: `Tools/calibrate/README.md`.

Hicri tarih sistemin Ümmü'l-Kura takviminden geliyor, Diyanet'in tarihinden ay
başlarında bir gün sapabilir.

## Doğrulamayı çalıştırma

```sh
swiftc -O EzanVakti/Core/*.swift Tools/validate/main.swift -o /tmp/validate && /tmp/validate
```

## Bildirimler

Vakit bildirimleri yerel (`UNCalendarNotificationTrigger`) — sunucu yok.

iOS bir uygulamaya **en fazla 64 bekleyen yerel bildirim** veriyor. Vakitler her gün
değiştiği için tekrarlayan tetikleyici kullanılamıyor, her vakit tek tek planlanıyor.
Bütçe 58'de tutuluyor ve uygulama her öne geldiğinde pencere ileri kaydırılıyor.
**Sonuç: kullanıcı uygulamayı ~2 hafta hiç açmazsa bildirimler kesilir.** Sunucusuz
bir tasarımda bunun etrafından dolaşmak mümkün değil; bilinen ve kabul edilmiş sınır.

Ekranda "N bildirim planlandı" satırı bilerek duruyor — bu özellikte sessiz
başarısızlık en pahalı hata türü.

### Bildirim sesi

iOS'un ses dosyası kuralları katı ve **sessiz başarısız**: dosya pakette yoksa, adı
yanlışsa veya 30 saniyeyi geçiyorsa hata vermeden sistem sesine düşer. Bu yüzden
`NotificationSoundCatalog` çalışma zamanında paketi kontrol ediyor ve ayarlarda
yalnızca gerçekten var olan sesler listeleniyor; seçili ses kayboldu ise ekran uyarıyor.

Zorunluluklar:

| | |
|---|---|
| Codec | Linear PCM, IMA4, µLaw, aLaw |
| Konteyner | `.caf`, `.aiff`, `.wav` — **MP3 ve M4A çalışmaz** |
| Süre | en fazla 30 saniye |
| Konum | `EzanVakti/` klasörünün kökü (alt klasör değil) |

Dönüştürme:

```sh
Tools/make-sound.sh ~/Downloads/ezan.mp3 ezan-kisa
```

Betik süreyi kontrol ediyor, 30 sn'yi aşarsa `ffmpeg` ile kırpıyor (`brew install ffmpeg`),
`afconvert` ile IMA4/CAF'e çeviriyor ve doğrudan `EzanVakti/` içine yazıyor. Sonrasında
Xcode'da yeniden derlemek yeterli — dosya senkronize klasörde olduğu için proje
dosyasına dokunmak gerekmiyor.

Kesim noktasını kelime ortasına düşürmemek için önce boşlukları gör:

```sh
ffmpeg -i girdi.mp3 -af silencedetect=noise=-32dB:d=0.30 -f null - 2>&1 | grep silence_
```

Betik seviyeyi iki geçişli `loudnorm` ile **−16 LUFS**'a getiriyor; farklı
kaynaklardan gelen sesler aynı yükseklikte çalsın diye. Sonda 0.4 sn fade var.
Yeni bir ad kullanırsan `NotificationSoundCatalog.all` listesine eklemelisin.

### Pakete konan sesler

| Dosya | Süre | Kaynak | Lisans |
|---|---|---|---|
| `tekbir.caf` | 7.8 sn | [Adhan.ogg](https://commons.wikimedia.org/wiki/File:Adhan.ogg) | CC0 |
| `ezan-kisa.caf` | 11.6 sn | [Oración Al-Azzan.ogg](https://commons.wikimedia.org/wiki/File:Oraci%C3%B3n_Al-Azzan.ogg) | PD-self |
| `ezan-orta.caf` | 23.3 sn | [Adhan.ogg](https://commons.wikimedia.org/wiki/File:Adhan.ogg) | CC0 |
| `ezan-tam.caf` | 29.5 sn | [Beautiful adhan.ogg](https://commons.wikimedia.org/wiki/File:Beautiful_adhan.ogg) | CC0 |

Hepsi Wikimedia Commons'tan, hepsi "own work" beyanıyla CC0 veya PD-self. CC0 atıf
zorunluluğu getirmiyor; tablo yine de kaynağı izlenebilir tutmak için burada.

`tekbir` ve `ezan-orta` aynı kayıttan, diğer ikisi farklı okuyuculardan — sesler
arasında geçiş yaparsan okuyucu değişir.

**Dikkat:** Commons'taki "own work" beyanları yükleyenin kendi bildirimi, bağımsız
olarak doğrulanamıyor. Uygulamayı yayınlamayı düşünüyorsan kaynağı kendin teyit et.

### Henüz yapılmayanlar

- **Tam ezan çalınamıyor** — 30 saniye sınırı yüzünden bildirim sesi olarak yalnızca
  kısa bir kesit mümkün. Tam ezan için ya uygulama önde olmalı (AVAudioPlayer) ya da
  Apple Watch haptic yolu tercih edilmeli.
- `.timeSensitive` kesme seviyesi odak modlarını aşar ama ayrı entitlement istiyor;
  imzalamayı bozmamak için varsayılan seviyede bırakıldı.
- **Critical alert** (sessizdeyken bile çalma) Apple'dan özel onay gerektiriyor.

## Görünümleri Xcode'suz görme

`Tools/render` bir görünümü `ImageRenderer` ile PNG'ye basıyor:

```sh
swiftc -O EzanVakti/Features/Qibla/QiblaDial.swift Tools/render/main.swift -o /tmp/render && /tmp/render
```

Kâbe işaretinin görünmemesi bu yolla teşhis edildi: işaret aslında çiziliyordu ama
12×10 pt boyutunda, kadranla birlikte 152° yatmış ve tam çentik halkasının üstündeydi —
ekranda leke gibi duruyordu. Aynı render iki kusuru daha ortaya çıkardı: güney harfi
"G" baş aşağı dönüyordu ve Kâbe kuşağı `nonzero` doldurma yüzünden oyulmuyordu.

Bu yüzden `QiblaDial` ve `KaabaGlyph` ayrı bileşenler: servis bağımlılığı olmadan
tek başlarına render edilebiliyorlar. Görsel bir parça eklerken aynı yolu izlemek
işe yarıyor.

### Hedef bazlı derleme denetimi

```sh
Tools/check/targets.sh
```

Bütün dosyaları tek klasöre kopyalayıp derlemek **hedef üyeliği hatalarını
gizliyor.** Gerçek örnek: `Palette.swift` widget hedefine eklendi ama bağlı
olduğu `ScaledFont.swift` eklenmedi — düz denetim geçti, Xcode derlemesi
patladı. Betik `membershipExceptions` listesini pbxproj'dan okuyor, yani elle
güncellenmiyor.

### Render aracının sınırı

Basılan görünüm gerçek düzenin **esnekliğini** de taklit etmeli. Kaydırma alanına
sabit yükseklik verilirse dikeyde yayılan hatalar görünmez oluyor: sütun
başlığındaki `Color.clear.frame(width:)` yalnız genişlik aldığı için dikeyde açgözlü
davranıp başlığı ekranın yarısı kadar şişirmişti, sabit yükseklikli render bunu
gizledi ve hata ancak cihazda ortaya çıktı.

Doğrusu `GeometryReader` ile: mevcut alanı kapla, içeriği ona kırp — ScrollView gibi.

### Uygulama ikonu

```sh
swiftc -O EzanVakti/Features/Qibla/KaabaGlyph.swift Tools/icon/main.swift -o /tmp/icon
/tmp/icon ~/Downloads/ezan-ikon-adaylari
```

Dört aday üretiyor: Kâbe (krem / lacivert), hilal, kubbe+minare. **Kullanılan: hilal**
(`Assets.xcassets/AppIcon.appiconset/AppIcon.png`). Kâbe adayları
uygulamadaki `KaabaGlyph`'i kullanıyor, yani ikon ile kıble işareti aynı çizim.

İki App Store kuralı koda gömülü:

- **Alfa kanalı olmamalı.** `ImageRenderer` her zaman alfalı görüntü veriyor;
  `noneSkipLast` bir `CGContext`'e yeniden çizip `CGImageDestination` ile
  yazıyoruz. `NSGraphicsContext` + alfasız `NSBitmapImageRep` yolu denendi,
  simsiyah çıktı verdi. `sips -g hasAlpha` ile doğrulanabilir.
- **Köşeler yuvarlatılmamalı** — sistem kendisi maskeliyor.

Ölçüler orana bağlı; mutlak punto verilen ilk sürüm küçük boyutta render
edilince taşıyordu ve karşılaştırma yanıltıcı oluyordu.

### Kâbe işareti

`KaabaGlyph` hazır bir görsel değil, SwiftUI ile çizilmiş vektör: telif sorunu yok,
her boyutta keskin, renklendirilebilir, ayrı çözünürlük dosyaları gerekmiyor.

Render, tek başına bakınca görülmeyecek bir sorunu ortaya çıkardı: Kâbe gövdesi koyu
olduğu için koyu kadran üzerinde kayboluyor, küçük boyda yalnızca altın şeritler
görünüyordu. Bu yüzden işaret **açık renk bir rozetin içine** alındı. 14 pt'ye kadar
okunabilirlik `Tools/render`'daki boyut testiyle kontrol edildi.

## Kıble

İki parça: **yön** (pusula) ve **kıble saati** (güneşin kıble yönüne geldiği an).

Konum sağlayıcı sekmeler arasında paylaşılıyor — tek `CLLocationManager`, tek izin
sorusu. Pusula yalnızca kıble ekranı görünürken açık; sürekli açık tutmak pil yiyor.

### Doğrulama

Kıble yönü, Aladhan'ın bağımsız uygulamasına karşı dünya genelinde ölçüldü:

| Şehir | Hesap | Aladhan | Fark |
|---|---|---|---|
| İstanbul | 151.62° | 151.62° | 0.00° |
| Ankara | 160.17° | 160.17° | 0.00° |
| New York | 58.48° | 58.48° | 0.00° |
| Londra | 118.99° | 118.99° | 0.00° |
| Jakarta | 295.15° | 295.15° | 0.00° |
| Sidney | 277.50° | 277.50° | 0.00° |
| Cape Town | 23.35° | 23.35° | 0.00° |
| Tromsø | 154.28° | 154.28° | 0.00° |

En büyük sapma 0.02° (Mekke'nin hemen yanında).

Kıble saati gerçek Diyanet `KibleSaati` alanıyla karşılaştırıldı (İstanbul, 17 gün):
**14/17 tam isabet**, kalanında 1 dk. Diyanet dakikayı yukarı yuvarlıyor; model tam
anı tutuyor, yuvarlama yalnızca gösterimde yapılıyor. Güneş dakikada 0.25° hareket
ettiği ve gölgeyle kıble okumanın hassasiyeti bundan çok daha kaba olduğu için
saniyelik düzeltme eklenmedi.

### Uç durumlar

`qiblaTimes` gün içinde **hiç** veya **iki** kesişim döndürebilir; ikisi de gerçek:

- New York (Ağustos): kıble 58° kuzeydoğu, güneş o azimuta ancak gündoğumundan önce
  ulaşıyor → o tarihte kıble saati yok.
- Jakarta: gün içinde iki kesişim çıkıyordu, biri gece yarısına düşüyordu.

Azimut hesabı güneş ufkun altındayken de sonuç ürettiği için kesişimler **irtifa > 0**
koşuluyla süzülüyor — gölge olmayan bir an kıble saati sayılamaz.

## Namaz takibi & kaza

Her vakit dört durumda: işaretsiz / kıldım / cemaatle / kılmadım. Satıra dokundukça
sırayla geçiyor. Cemaat de "kılınmış" sayılıyor.

### Kaza borcu üç bileşenden türetiliyor

```
borç = birikmiş borç (kullanıcı girer)
     + "kılmadım" işaretli vakit sayısı (kayıttan türetilir)
     - kaza olarak kılınıp düşülenler
```

Tek bir sayaç tutup elle artırıp azaltmak yerine böyle yapılmasının nedeni çift
sayma: kullanıcı bir işareti düzeltince borcun da kendiliğinden düzelmesi gerekiyor.
Türetilmiş olduğu için bu bedava geliyor.

**Kaçırılan vakitler otomatik sayılmıyor.** Uygulama açılmadığı için işaretlenmemiş
bir vakit ile gerçekten kılınmamış bir vakit ayırt edilemez; tahmin etmek yerine
kullanıcının açıkça "Kılmadım" demesi bekleniyor.

### Seri

Bugünden geriye kesintisiz tam gün sayısı. Bugün henüz tamamlanmadıysa seri dünden
sayılıyor — aksi halde gün ortasında uygulamayı açan herkesin serisi sıfır görünürdü.

### Saklama

`PrayerLogStore` dosyaya JSON yazıyor. SwiftData yerine bunun seçilmesinin nedeni
test edilebilirlik: mağaza saf Foundation olduğu için Xcode olmadan koşulabiliyor.
Veri de küçük (bir yıl ≈ 1825 kayıt). İleride SwiftData veya CloudKit'e geçilirse
değişiklik bu sınıfla sınırlı kalır.

`Prayer`, `CodingKeyRepresentable` uyguluyor; olmasa Swift `[Prayer: X]` sözlüklerini
anahtar/değer dizisine çevirir ve dosya okunaksız olurdu.

### Testler

```sh
swiftc -O EzanVakti/Core/Prayer.swift EzanVakti/Core/PrayerRecord.swift \
       EzanVakti/Core/PrayerLogStore.swift Tools/tests/main.swift -o /tmp/tests && /tmp/tests
```

31 kontrol: durum geçişleri, gün tamamlanması, seri kuralları, kaza aritmetiği
(çift sayma ve negatife düşme dahil), diske yazıp geri okuma, JSON'un okunabilirliği.

## Widget

Kaynaklar `WidgetSources/` altında hazır bekliyor. **Hedefin kendisi Xcode'da
oluşturulmalı** — ayrıntı aşağıda.

### Neden proje dosyasına elle eklenmedi

Widget ayrı bir uygulama uzantısı hedefi: gömme derleme fazı, hedef bağımlılığı,
`NSExtension` Info.plist anahtarları, ayrı yetkilendirme. Bunları elle yazılmış bir
`project.pbxproj`'a eklemek doğrulanamıyor — geçerli bir plist üretmek derlenebilir
bir hedef üretmek demek değil, ve hata durumunda **çalışan proje bozulur**. Xcode'un
şablonu bu bağlantıyı doğru kuruyor, üç tıklık iş.

### Kurulum

1. **File → New → Target… → Widget Extension**
   - Product Name: `EzanVaktiWidget`
   - "Include Live Activity" ve "Include Configuration App Intent" **işaretsiz**
     (StaticConfiguration kullanıyoruz)
   - Finish → şema sorulunca Activate
2. Xcode'un ürettiği şablon `.swift` dosyalarını **sil**. Özellikle `@main` içeren
   bundle dosyasını: iki `@main` derlenmez.
3. `WidgetSources/*.swift` dosyalarını yeni `EzanVaktiWidget/` klasörüne taşı.
4. Şu `Core` dosyalarını widget hedefine de ekle (dosyayı seç → sağ panel →
   Target Membership → EzanVaktiWidget):
   `SolarMath.swift`, `Prayer.swift`, `PrayerCalculationParameters.swift`,
   `PrayerTimesCalculator.swift`, `SharedLocationStore.swift`
5. **App Group** — her iki hedefe: Signing & Capabilities → + Capability →
   App Groups → `group.com.mahmud.ezanvakti`
6. Widget hedefinin deployment target'ını 17.0 yap (uygulamayla aynı).

### Kurulumda çıkan tuzaklar

- **`Info.plist`'te anahtar adı.** Xcode'un plist editörü `NSExtension` anahtarını
  ekranda "Application Extension" diye gösteriyor. Bu görünen ad dosyaya ham anahtar
  olarak yazılırsa iOS `NSExtension`'ı bulamıyor ve kurulumu reddediyor:
  *"Appex bundle ... does not define an NSExtension dictionary"*. Dosyada anahtar
  birebir `NSExtension` olmalı.
- **Hedefi iki kez oluşturmak.** Aynı bundle ID ve aynı `.appex` adıyla iki hedef
  oluşursa gömme fazı appex'i iki kez kopyalar ve derleme kırılır. Fazladan olanı
  hedef listesinden silmek gerekiyor.
- **App Group adı** iki hedefte birebir aynı olmalı; `SharedLocationStore.appGroupID`
  ile de eşleşmeli.

### App Group olmadan da çalışır

Widget kendi konum iznini isteyemiyor; uygulama konumu çözdüğünde
`SharedLocationStore` üzerinden paylaşıyor. App Group kurulamazsa (ücretsiz
provisioning'de kısıtlı olabilir) widget İstanbul'a düşüyor — ve bunu
**"İstanbul (varsayılan)"** yazıp konum-kapalı simgesiyle ekranda söylüyor.
Sessizce yanlış şehrin vakitlerini göstermiyor.

### Tasarım

Widget'lar uygulamanın diliyle aynı: `Palette` widget hedefine de bağlı, sıradaki
vakit altın vurguda, vakit adı Türkçe-güvenli büyük harfle. Ana ekran
widget'larının altında ilerleme çubuğu var — hem boşluğu dolduruyor hem geçen
oranı gösteriyor.

Kilit ekranı görünümleri **renk kullanmıyor**: sistem onları tek renge tonluyor,
altın vurgu orada kaybolurdu.

Geri sayım her yerde `Text(timerInterval:)`. Uygulamadaki sakin biçim
("1 sa 46 dk") burada kullanılamıyor: çizelge yalnızca vakit geçişlerinde girdi
ürettiği için durağan bir metin bir dakika içinde yanlış olurdu.

### Zaman çizelgesi

Vakitler belirlenimci olduğu için çizelge bir gün ileriye kadar baştan üretiliyor —
ağ yok, tahmin yok. Girdiler yalnızca **vakit geçişlerinde** (günde ~6): geri sayım
`Text(timerInterval:countsDown:)` ile kendi kendine ilerlediğinden dakikalık girdi
üretmeye gerek yok, WidgetKit'in girdi bütçesi böylece harcanmıyor.

İlerleme halkası bir önceki vakitten sıradakine olan oranı gösteriyor. Gece yarısı
ile imsak arasında bugünün listesinde önceki vakit bulunmadığı için **dünün
yatsısına** düşülüyor; aksi halde halka gece yarısında sıfırlanıyordu.

Boyutlar: kilit ekranı (satır içi, dairesel, dikdörtgen) + ana ekran (küçük, orta).

## Yakındaki camiler

Türkiye içinde veri **uygulamayla paketli** — ağ hiç kullanılmıyor. Yurtdışında
OpenStreetMap Overpass API'sine gidiliyor. İkisinde de aynı OSM etiketleri:
`amenity=place_of_worship` + `religion=muslim`.

### Paketlenmiş veri

| | |
|---|---|
| Kayıt | **45.833 cami** |
| Dosya | `EzanVakti/tr-mosques.txt`, 1.35 MB |
| OSM anlık görüntüsü | 2026-08-22T13:23:00Z |
| Ayrıştırma (tek seferlik, tembel) | 33 ms |
| Sorgu | 0.02–0.04 ms |

Biçim satır başına `enlem;boylam;ad`. JSON yerine bu seçildi: 45 bin kayıtta
ayrıştırma yükü belirgin şekilde az ve uygulama tarafı tek `split` ile okuyor.
Mekânsal indeks yok — kayıtlar bellekte ~4 MB tutuyor ve kutu ön elemesiyle
tarama milisaniye altında kalıyor, bu ölçekte indeks gereksiz karmaşıklık olurdu.

Kapsama kabaca Türkiye sınırları (`BundledMosqueSource.coverage`). Kutu sınır
bölgelerini de kapsadığı için Suriye/Irak şeridinde ~390, Kıbrıs'ta birkaç kayıt
var; sınır illerindeki kullanıcı için faydalı, zararı yok.

**Adsız kayıtlar dahil.** Çıkarımda okunan 50.212 elemanın 28.558'i adsızdı ve
bunların **%95'i `building=mosque`** taşıyor — kırsalda cami sık sık adsız
işaretleniyor. Atmak veri setinin yarısını çöpe atmak olurdu; `building`
etiketi yeterli sinyal, listede "Cami" olarak görünüyorlar.

Yeniden üretmek: `Tools/mosque-extract/extract.py`.

### Neden paketlendi

Overpass topluluk sunucusu ve kullanım kuralları yayınlanmış bir uygulamadan
gelen düzenli trafiği kapsamıyor. Üstelik ölçümde yanıt süresi 1.5–14 sn
arasında değişiyordu ve arada 504 dönüyordu. Paketlenmiş veriyle sonuç anında
geliyor, çevrimdışı da çalışıyor. Bedeli: veri uygulama güncellemesiyle
tazeleniyor.

### Neden Apple değil

Önce `MKLocalSearch` kullanılıyordu. Gerçek çağrılarla ölçüldü ve bu iş için
elverişsiz olduğu görüldü:

| | Apple `MKLocalSearch` | OpenStreetMap |
|---|---|---|
| Eyüpsultan, 1 km | **2 cami** | **34 cami** |
| Konya merkez, 1 km | — | 59 cami |
| Sonuç tavanı | istek başına 25, sayfalama yok | yok |
| Sıralama | ünlülüğe göre | yarıçap sunucuda süzülüyor |

Apple 1 km yarıçapta dönen 25 sonucun yalnızca 2'sini gerçekten 1 km içinde
veriyordu; gerisi kilometrelerce ötedeki meşhur camilerdi (Süleymaniye, Fatih…).
Bölgeyi karolara bölmek kısmen işe yarıyor (2 → 9) ama istek sayısı artınca Apple
throttle uyguluyor: 25 isteğin 15'i reddedildi, sonrasında hepsi.

Apple Haritalar uygulamasının kendisi bu genel API'yi kullanmıyor; kendi iç,
yakınlığa göre sıralı indeksine erişimimiz yok.

### Geçişin getirdiği sadeleşme

OSM'de ibadet yerleri etiketli olduğu için isimden tahmin yürütme makinesi
tamamen kalktı: üç ayrı sorgu, isim gövdesi eşleştirme, kategori eleme listesi ve
istemci tarafı yarıçap süzmesi silindi. `MKLocalSearch` döneminde "FATİH CAMİİ"
gibi büyük harfli adların eşleşmemesi ve "Cami Sokak Kuaför" gibi yanlış
eşleşmeler de birer sorundu; ikisi de kendiliğinden ortadan kalktı.

### Tekke, medrese, türbe ayıklama

OSM'de bunlar da `amenity=place_of_worship` + `religion=muslim` etiketli ve
etiketleri gerçek camilerden **ayırt edilemiyor**: "Şeyhülislâm Mustafa Efendi
Tekkesi" de `building=mosque` + `denomination=sunni` taşıyor, `historic` veya
`disused` etiketi hiçbirinde yok.

Ayırt eden tek şey ad. Bu yüzden adında cami/mescit/mosque geçmesi şartı var.
Ölçüldü: Eyüpsultan'da 34 kaydın 32'si geçiyor, elenen ikisi tam da namaz
kılınmayan yerler ("Sokullu Mehmet Paşa Medresesi", "Şeyhülislâm Mustafa Efendi
Tekkesi"). Adında "Mescit" geçen külliye bölümleri listede kalıyor.

### Hız

Overpass topluluk sunucusu ve yavaş: aynı sorgu ölçümde 1.5 sn ile 14 sn arasında
değişti, arada 504 döndü. Hızlı ayna diye bir şey yok — kumi.systems ve
private.coffee de 502 verdi.

İki önlem:

- **Yedekli sunucu**: üç sunucu sırayla deneniyor.
- **Disk önbelleği** (`MosqueCache`, 30 gün): camiler yer değiştirmiyor. Ölçüm —
  ilk çağrı 708 ms, ikinci **0 ms**. Anahtar ~100 m'ye yuvarlanıyor; uzaklık ve
  yön önbellekten okunmuyor, çağıran konuma göre yeniden hesaplanıyor.

### Ulaşım biçimi

Yol tarifi seçili yarıçaptan türüyor: **1 km yürüyerek, 5 ve 25 km araçla.**
Apple `dirflg`, Google `directionsmode`, Yandex Haritalar `rtt` parametreleriyle.
Yandex Navigasyon araç navigasyonu olduğu için onda yaya kipi yok.

### Notlar

- Overpass yük altında 429/504 döndürüyor; bunlar "internet yok"tan ayrı
  mesajlarla gösteriliyor, yoksa kullanıcı yanlış yere bakar.
- ODbL kaynak belirtmeyi şart koşuyor: listenin altında atıf satırı var.
- Adres etiketleri OSM'de seyrek (34 caminin 2'sinde `addr:street` var); adres
  satırı çoğu zaman boş kalıyor, ekran bunu zaten kaldırıyor.

## Erişilebilirlik

### Pusula performansı

Çentikler, yön harfleri ve derece yazıları tek bir `Canvas` ile çiziliyor.
Önce her çentik ayrı bir `Rectangle` + `offset` + `rotationEffect` idi; 72 çentik
ve yazılarla karede 81 dönüşüm katmanı hesaplanıyordu. Pusula ekranı yön
güncellemesi hızında yeniden çizildiği için bu gözle görülür takılmaya yol
açıyordu.

Ölçüm (`Tools` altındaki render altyapısıyla, 40 kare):

| | ms/kare |
|---|---|
| Ayrı görünümler | **2.14** |
| Canvas | **0.45** |

İki şey daha kaldırıldı: erişilebilirlik etiketi kadran konteynerinden alınıp
ortadaki göstergeye taşındı (konteynerde toplamak, yön her değiştiğinde
erişilebilirlik ağacını yeniden kurduruyordu) ve değer 15°'lik kademeye
yuvarlandı. Hızla değişen derece yazısındaki `contentTransition(.numericText())`
da kaldırıldı.

### VoiceOver

Önceden hiç erişilebilirlik etiketi yoktu; pusula ve takip düğmeleri VoiceOver
kullanıcısı için tamamen anlaşılmazdı. Şimdi:

- **Kıble pusulası** tek öğede toplanıp durum sözle veriliyor
  ("60 derece sağa dön" / "Kıble yönündesin"). Kadran, ok ve çentikler
  görsel olduğu için gizlendi.
- **Liste satırları** tek cümle okunuyor: "İkindi 16:58, şu anki vakit,
  bildirim açık". Ayrı ayrı "İkindi", "16:58", "zil" duymak bir şey anlatmıyor.
- **İmsakiye satırı** altı vakti birlikte okuyor; sütun sütun okunsa hangi
  sayının hangi vakit olduğu kaybolurdu.
- **Takip düğmeleri** etiket + değer + ipucu üçlüsü taşıyor: dokundukça durum
  değiştiği için "ne olduğu, hangi durumda, ne olacağı" gerekiyor.
- Yalnızca ikon içeren düğmelerin hepsi etiketlendi; dekoratif ikonlar gizlendi.

### Dynamic Type

53 çağrı sabit punto veriyordu (`.font(.system(size:))`), yani kullanıcı yazıyı
büyütse de uygulamada **hiçbir şey değişmiyordu**. Hepsi `scaledFont`'a çevrildi;
çarpan ortamdaki `dynamicTypeSize`'dan okunuyor.

`UIFontMetrics` yerine bu yol seçildi çünkü platformdan bağımsız: `ImageRenderer`
ile istenen boyutta render edip düzeni gözle denetlenebiliyor.

Denetim işe yaradı: **imsakiye tablosu 1.9x puntoda tamamen kırılıyordu** —
altı sütun 393 pt'ye sığmadığı için bütün saatler "04:…" diye kırpılıyordu.
Erişilebilirlik boyutlarında satır artık blok düzenine geçiyor (gün başlığı
üstte, vakitler ikili sütunlarda) ve sütun başlığı gizleniyor.

## Dil

Uygulama **yalnızca Türkçe**. Bu bilinçli: kendisi ve çevresi için yapıldı,
tek dilli uygulama App Store'da sorun değil.

`EzanVakti/Localizable.xcstrings` kaynak dili `tr` olarak eklendi. Faydası,
uygulamanın Türkçe yerelleştirmesini beyan etmesi: aksi halde İngilizce cihazda
bizim metinler Türkçe, sistemin verdiği metinler İngilizce görünüp karışık bir
arayüz oluyor.

Başka dil eklemek isteyen için bilinmesi gerekenler:

- SwiftUI'da `Text("...")` literalleri zaten `LocalizedStringKey`, yani 32
  metnin çoğu anahtar olarak hazır. Ancak **11'i interpolasyonlu** — çevirmen
  için dizim ve çoğullama tuzağı, bunların yeniden yazılması gerekir.
- `Core` içinde 31 satır sabit Türkçe döndürüyor (`Prayer.title`,
  `PrayerStatus.title`, `MapApp.title`…). Bunlar `LocalizedStringResource`'a
  çevrilmeden kataloğa girmiyor.

## Gizlilik manifestosu

`EzanVakti/PrivacyInfo.xcprivacy` ve `EzanVaktiWidget/PrivacyInfo.xcprivacy`.
2024'ten beri App Store'a gönderim için zorunlu.

Kod taramasıyla belirlendi — hangi "gerekçe bildirilmesi gereken" API'ler
gerçekten kullanılıyor:

| Kategori | Kullanılıyor mu |
|---|---|
| UserDefaults | **evet** |
| Dosya zaman damgası | hayır |
| Disk alanı | hayır |
| Sistem açılış zamanı | hayır |
| Etkin klavyeler | hayır |

Gerekçe kodları Apple'ın kendi dokümanından doğrulandı (hafızadan yazılmadı):

- **`CA92.1`** — yalnızca uygulamanın kendisine açık user defaults
  (`NotificationPreferencesStore`, `UserDefaults.standard`)
- **`1C8F.1`** — aynı App Group içinde paylaşılan user defaults
  (`SharedLocationStore`, `LocationPreferenceStore`, `MapAppPreferenceStore`)

Widget yalnızca App Group suite'ini kullandığı için orada sadece `1C8F.1` var.
Anahtar adının `NSPrivacyAccessedAPITypeReasons` olduğuna dikkat —
`NSPrivacyAccessedAPIReasons` değil.

### Veri toplama beyanı

`NSPrivacyTracking` = false, `NSPrivacyCollectedDataTypes` boş, üçüncü taraf
SDK yok.

Bu bir yorum barındırıyor: yurtdışında cami ararken koordinat Overpass'a
gönderiliyor. Apple'ın "toplama" tanımı, veriyi *isteği gerçek zamanlı
karşılamak için gerekenden uzun süre* cihaz dışında tutmak; Overpass isteği
anında işleyip bizim adımıza saklamıyor, dolayısıyla toplama sayılmıyor.
Yurt içinde veri paketli olduğu için hiçbir şey gönderilmiyor.

**Analitik, çökme raporlama veya hesap sistemi eklenirse bu beyan güncellenmeli.**

## Live Activity (kilit ekranı + Dinamik Ada)

Sıradaki vakte kalan süre kilit ekranında ve Dinamik Ada'da görünüyor.
Ayrı hedef gerekmedi: ActivityKit arayüzü var olan widget uzantısının içinde.

| Sunum | İçerik |
|---|---|
| Kompakt sol | Vakit ikonu (altın) |
| Kompakt sağ | Canlı geri sayım |
| Minimal | Vakit ikonu |
| Genişletilmiş | Vakit adı · saati · ilerleme çubuğu · konum + kalan |
| Kilit ekranı kartı | Küçük widget'a yakın: etiket, saat, geri sayım, ilerleme |

### Kendi kendine ilerleyen bileşenler

Geri sayım ve ilerleme çubuğu `timerInterval` alan sürümlerle kuruluyor. Sebep
her ikisinde de aynı: sistem bu görünümleri yalnızca içerik güncellendiğinde
yeniden çiziyor.

Widget'ta bu **gerçek bir hataydı**: zaman çizelgesi yalnızca vakit
geçişlerinde girdi ürettiği için ilerleme girdi oluşturulduğu anda her zaman 0
oluyordu; çubuk saatlerce %0'da donuk kalıp sonra sıçrıyordu.

### Eşik: vakte çok varsa görünmüyor

Varsayılan **2 saat**; ayarlanabilir (1 / 2 / 3 saat).

Ölçüm bunu iki ayrı sebeple gerektirdi. İstanbul'da yıl boyunca vakitler arası
süre:

| Geçiş | en kısa | en uzun |
|---|---|---|
| Akşam → Yatsı | 79 dk | 111 dk |
| İmsak → Güneş | 84 dk | 120 dk |
| Öğle → İkindi | 139 dk | 240 dk |
| İkindi → Akşam | 142 dk | 217 dk |
| Güneş → Öğle | 290 dk | 466 dk |
| **Yatsı → İmsak** | 286 dk | **691 dk** |

1. Geçişlerin **yarısı 3 saatten uzun**. Altı saatlik bir geri sayım kimseye bir
   şey söylemiyor, sadece adayı ve kilit ekranını işgal ediyor.
2. Yatsı–İmsak kışın **11.5 saate** çıkıyor ve Live Activity'nin **8 saatlik**
   ömür sınırını aşıyor; etkinlik vakit gelmeden sistemce bayatlatılırdı.

2 saatlik eşikle kısa geçişler (İmsak–Güneş, Akşam–Yatsı) tümüyle kapsanıyor,
uzunlarda yalnızca son iki saat görünüyor.

### Arka planda başlatma

**iOS 26+:** etkinlikler ileri tarihe zamanlanıyor
(`Activity.request(..., start:)`) ve sistem uygulama arka plandayken bile
başlatıyor — **sunucu gerekmiyor**. Sıradaki 3 vakit için önceden kuruluyor.
Apple bu API'de `alertConfiguration` şart koşuyor: kullanıcı etkinliğin
başladığını bilmeli.

**iOS 26 öncesi:** `Activity.request` yalnızca uygulama öndeyken çalışıyor.
Tek istisna `LiveActivityIntent` (App Intents) — o da kullanıcı etkileşimi
gerektiriyor, zamanlanamıyor. Bu sürümlerde yalnızca uygulama açıldığında ve
vakit lead penceresindeyse etkinlik kuruluyor.

Zamanlanmış etkinlikler sistemin eşzamanlı etkinlik sınırına sayıldığı için
aynı anda 3 vakit kuruluyor.

### Doğrulanamayan

`ProgressView` macOS'ta `ImageRenderer` ile render edilmiyor (düz `value:`
alan sürümü de dahil — ortam kısıtı, API sorunu değil). Çubuğun cihazdaki
görünümü denetlenmedi. ActivityKit da iOS'a özel olduğu için
`PrayerActivityAttributes`, `PrayerLiveActivity` ve `LiveActivityController`
macOS tip denetiminin dışında.

## Konum seçimi

Varsayılan GPS; ana ekranda konum adına dokununca şehir/ilçe aranıp elle seçilebiliyor.

- **Elle seçim yapıldığında GPS hiç açılmıyor** — `LocationProvider` bu durumda
  konum yöneticisine dokunmuyor, gelen güncellemeleri ve yetki değişimlerini
  yok sayıyor. Pil ve mahremiyet açısından doğrusu bu.
- Tercih App Group'ta saklanıyor, seçim `SharedLocationStore`'a doğrudan yazılıyor:
  widget da aynı konumu kullanıyor. Ekranlardan birinin görünür olmasına
  bağlı kalırsa widget seçimi kaçırabilirdi.
- "Konumumu kullan" ile otomatik moda dönülüyor.

Arama `MKLocalSearch` ile yapılıyor; **tek internet gerektiren yer burası.** Seçim
yapıldıktan sonra koordinat saklandığı için vakitler yine çevrimdışı hesaplanıyor.
Arama başarısız olursa boş liste yerine açık bir hata gösteriliyor.

Şehir listesi bilerek pakete gömülmedi: 81 il yeterli değil (İstanbul boylamda ~1.5°
yayılıyor, bu ~6 dakika fark demek), ilçe listesi ise doğruluğu denetlenmesi gereken
bir veri seti olurdu. Arama hem yurt dışını da kapsıyor hem doğrulama yükü getirmiyor.

## İmsakiye

Aylık vakit çizelgesi; Ramazan'da klasik imsakiye işlevini görüyor.

- Ay ileri/geri gezinme, başka aydayken "Bugün" düğmesi
- Bugünün satırı altın kenar çubuğu + zeminle işaretli, açılışta o satıra kaydırılıyor
- Ay başlığı **ve** sütun adları kaydırma alanının dışında; yalnızca gün satırları
  kayıyor, hangi sütunun hangi vakit olduğu her zaman görünür
- **Ramazan farkındalığı:** ay Ramazan'a değiyorsa İmsak ve Akşam sütunları altına
  dönüyor. Hicri ay Ümmü'l-Kura takviminden okunuyor, gün bazında kontrol ediliyor;
  yani ayın ortasında başlayan Ramazan'da sadece ilgili satırlar vurgulanıyor.
- Hicri başlık iki ayı kapsıyorsa yıl bir kez yazılıyor ("Şaban – Ramazan 1448")

Tüm satırlar aynı çekirdekle hesaplanıyor, ay bazında önbelleğe alınıyor.

Sütun genişlikleri `ImsakiyeLayout` üzerinden paylaşılıyor: sabit başlık ile kayan
satırlar iki ayrı görünüm olduğu için genişlik iki yerde tanımlanırsa hizalama
sessizce kayar — tek kaynak bunu engelliyor.

## App Store gönderimi

Projede hazır olanlar: uygulama ikonu (paketten doğrulandı), gizlilik
manifestosu, `ITSAppUsesNonExemptEncryption = false` (ihracat uyumluluğu sorusunu
atlatıyor), Türkçe konum izni metni, her iki hedefte "Ezan Vakti" görünen adı.

Projede **eksik olan**: `DEVELOPMENT_TEAM` boş — dağıtım için ücretli üyelik ve
takım kimliği gerekiyor.

Xcode dışında yapılacaklar (App Store Connect):

- Apple Developer Program üyeliği (yıllık $99)
- App Store Connect kaydı ve bundle kimliğinin kaydı
- Ekran görüntüleri (6.9" ve 6.5" zorunlu)
- Açıklama, alt başlık, anahtar kelimeler, destek URL'si
- **Gizlilik politikası URL'si** — konum eriştiği için zorunlu
- Yaş sınırı anketi
- App Privacy beyanı (nutrition labels) — `PrivacyInfo.xcprivacy`'den ayrı,
  App Store Connect'te elle doldurulan bir form

Kalan tek teknik engel: **ezan sesi telifi**. Commons'taki "own work" beyanları
yükleyenin kendi ifadesi, bağımsız doğrulanamıyor.

## Apple Watch

Kaynaklar `WatchSources/` altında hazır; **hedefler Xcode'da oluşturulmalı**
(widget'ta olduğu gibi, elle `pbxproj` düzenlemek doğrulanamıyor).

### Kapsam

- **Vakitler ekranı**: konum, sıradaki vakit, geri sayım, altında kaydırılan liste
- **Komplikasyonlar**: dairesel, köşe, dikdörtgen, satır içi

Saat **telefonla veri paylaşmıyor**. Vakitler hesaplanabilir olduğu için saat
kendi konumunu alıp kendi hesaplıyor; telefon yanında olmasa da çalışıyor.
App Group iOS uygulamasıyla saat arasında paylaşılmıyor (ayrı cihazlar), saatteki
`SharedLocationStore` yalnızca saat uygulaması ile komplikasyonu arasında.

### Kıble neden yok

Bileği kıbleye çevirmek için kolu tuhaf bir açıda sabitlemek gerekiyor ve pusula
bilekte manyetik olarak daha az güvenilir. Daha önemlisi kıble **tekrarlanan bir
iş değil** — bir konumda bir kez bulunuyor. Saatin değeri bir bakışta alınan
tekrarlı bilgide; kıble oraya uymuyor, telefonda kalıyor.

### Namaz takibi neden yok

Saatten işaretlemek mantıklı olurdu ama telefonla senkron olmadan iki ayrı
kayıt oluşurdu. `WatchConnectivity` ayrı bir iş, v2'ye bırakıldı.

### Telefondaki `LocationProvider` neden kullanılmadı

O sınıf pusula yönü, elle konum seçimi ve App Group paylaşımı taşıyor; saatte
hiçbiri gerekmiyor ve pusula API'lerinin watchOS'taki durumu ayrı bir
belirsizlik. Saat için tek işi olan ayrı bir sağlayıcı yazıldı.

### Xcode kurulumu

1. **File → New → Target… → watchOS → App**, adı `EzanVaktiWatch`.
   "Include Complication"/widget uzantısını da işaretle.
2. Xcode'un ürettiği şablon `.swift` dosyalarını sil (`@main` çakışır).
3. `WatchSources/` içindekileri hedeflere dağıt:
   - Uygulama: `WatchApp`, `WatchPrayerTimesView`, `WatchPrayerTimesModel`,
     `WatchLocationProvider`
   - Komplikasyon: `WatchComplication`, `WatchComplicationViews`
4. Paylaşılan dosyaları her iki saat hedefine ekle (Target Membership):
   `Core/SolarMath`, `Core/Prayer`, `Core/PrayerCalculationParameters`,
   `Core/PrayerTimesCalculator`, `Core/Geo`, `Core/SharedLocationStore`,
   `Features/Palette`, `Features/ScaledFont`; komplikasyona ayrıca
   `EzanVaktiWidget/PrayerWidgetEntry`.
5. Konum izni metni saat hedefine de gerekiyor
   (`NSLocationWhenInUseUsageDescription`).

`Tools/check/targets.sh` dört hedefi de (iOS uygulama, iOS widget, saat
uygulaması, saat komplikasyonu) kendi dosya kümesiyle deriyor.

## v1 kapsamı

Tamam: vakitler ekranı, bildirimler, kıble, imsakiye, namaz takibi & kaza sayacı, widget.
