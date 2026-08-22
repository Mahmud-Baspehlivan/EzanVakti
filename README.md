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
Tools/calibrate/            temkin kalibrasyonu (15 ile karşı ölçüm)
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

Veri kaynağı **OpenStreetMap** (Overpass API): `amenity=place_of_worship` +
`religion=muslim`.

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

## v1 kapsamı

Tamam: vakitler ekranı, bildirimler, kıble, imsakiye, namaz takibi & kaza sayacı, widget.
