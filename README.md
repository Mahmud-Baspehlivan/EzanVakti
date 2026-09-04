# Ezan Vakti

iOS için namaz vakitleri uygulaması. Vakitler cihazda hesaplanır — ağ bağımlılığı ve
sunucu yok, uygulama tamamen çevrimdışı çalışır.

## Yapı

```
EzanVakti/                  iOS uygulaması hedefi
  Core/                     hesaplama çekirdeği (Foundation dışı bağımlılık yok)
    SolarMath.swift          Deg ad alanı: derece trigonometrisi, wrap, Jülyen gün
    PrayerTimesCalculator.swift
    PrayerCalculationParameters.swift
    Prayer.swift             vakitler + Coordinate + DailyPrayerTimes
    Qibla.swift              kıble yönü + güneş konumu + kıble saati
    PrayerLogStore.swift     namaz takibi ve kaza borcu (JSON dosya)
    PrayerMarking.swift      hangi namaz işaretlenebilir (vakti girmemişse hayır)
    PrayerSync.swift         saat ↔ telefon işaret alışverişinin biçimi (saf veri)
    RemainingTime.swift      kalan sürenin sözcüklü biçimi (telefon + saat ortak)
    SharedLocationStore.swift  App Group üzerinden paylaşılan konum (saf depo)
  Services/                 platform çerçeveleriyle temas eden katman
    LocationProvider.swift     konumun tek sahibi; paylaşımı da o yapıyor
    PrayerNotificationScheduler.swift
    LiveActivityController.swift
    WatchSyncController.swift  saatten gelen işaretleri kayda geçiren köprü
    MosqueFinder.swift / MosqueCache.swift / BundledMosqueSource.swift
  Features/                 ekran başına klasör: View (kabuk) + Content (saf) + ViewModel
    DesignSystem/            Palette, ScaledFont, SectionLabel, StatusStyle — özellik değil, dil
    RootView.swift           sekmeler; paylaşılan durumun kurulduğu tek yer
    PrayerTimes/ Qibla/ Imsakiye/ NearbyMosques/ Settings/ Tracking/
  PrivacyInfo.xcprivacy
EzanVaktiWidget/            WidgetKit uzantısı + Live Activity arayüzü
  PrivacyInfo.xcprivacy
EzanVaktiWatch Watch App/   watchOS uygulaması (kendi konumunu kendi çözüyor)
  WatchTrackingStore.swift  bilekten konan işaretin kuyruğu ve telefonla eşleşmesi
  WatchStatusPicker.swift   kıldım / cemaatle / kılmadım seçimi
  PrivacyInfo.xcprivacy
watch widget/               kadran komplikasyonu hedefi
  PrivacyInfo.xcprivacy
Tools/check/targets.sh      her hedefi kendi dosya kümesi, SDK'si ve izolasyon ayarıyla derler
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

Gün, yerel gece yarısına değil **UTC gece yarısına** çapalanıyor. Yaz saatine gece
yarısı geçen ülkelerde (Mısır, Lübnan, Küba, Şili) o gün yerel gece yarısı hiç var
olmuyor; takvim çapayı bir sonraki güne kaydırdığı için bütün vakitler bir saat
kayıyordu.

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
swiftc -O EzanVakti/Core/Prayer.swift EzanVakti/Core/Geo.swift \
       EzanVakti/Core/SolarMath.swift EzanVakti/Core/PrayerCalculationParameters.swift \
       EzanVakti/Core/PrayerTimesCalculator.swift EzanVakti/Core/Qibla.swift \
       Tools/validate/main.swift -o /tmp/validate && /tmp/validate
```

Dosyalar tek tek sayılıyor, `Core/*.swift` globu değil: `PrayerActivityAttributes.swift`
ActivityKit'e dayanıyor, o çerçeve macOS'ta yok ve glob derlemeyi kırıyor.

`/tmp/validate qibla` ikinci bir kip: kıble yönünü ve ay boyunca kıble saatlerini döküyor.

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

**Şu an yok — gönderim öncesi çıkarıldı.** Katalogda yalnız sistem sesi var.

Pakette dört kayıt vardı (`tekbir`, `ezan-kisa`, `ezan-orta`, `ezan-tam`), hepsi
Wikimedia Commons'tan "own work" beyanıyla CC0/PD-self olarak alınmıştı. Sorun
şu: o beyan **yükleyenin kendi ifadesi** ve bağımsız doğrulanamıyor. Yayınlanmış
bir uygulamada doğrulanamayan telif, sonradan kaldırılma riski demek — ve bu
riski almanın karşılığı yalnızca bir bildirim sesiydi.

Geri eklemek için: `Tools/make-sound.sh` ile dönüştür, `EzanVakti/` köküne koy,
`NotificationSoundCatalog.all`'a bir satır ekle. Başka yere dokunmak gerekmiyor —
katalog çalışma zamanında süzülüyor, ayar ekranı tek seçenek varken seçici yerine
düz satır gösteriyor, birden fazlası olunca seçici kendiliğinden geri geliyor.

Kaynak ararken üç yol var: telifi teyit edilmiş bir kayıt, kendi kaydın, ya da
lisansı satın alınmış bir kayıt.

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
swiftc -O EzanVakti/Features/Qibla/QiblaDial.swift EzanVakti/Features/Qibla/KaabaGlyph.swift \
       EzanVakti/Features/DesignSystem/Palette.swift EzanVakti/Features/DesignSystem/ScaledFont.swift \
       EzanVakti/Core/Prayer.swift Tools/render/main.swift -o /tmp/render && /tmp/render
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

### Geçmiş günler işaretlenebiliyor

Yukarıdaki kural tek başına bir delik açıyordu: yalnız bugün işaretlenebildiği
için **uygulamanın açılmadığı bir gün sonsuza kadar çözümsüz kalıyordu.** O günün
vakitleri ne kılınmış ne kılınmamış sayılıyor; seri onarılamıyor ve gerçekten
kaçırılanlar kaza borcuna hiç girmiyor. Yani uygulama "tahmin etmem, sen söyle"
diyor ama söyleyecek yeri vermiyordu.

Hafta şeridindeki gün sütununa dokunmak o günü açıyor (`DayDetailView`); içeride
"Bugün" kartıyla aynı satırlar. Dokunma hedefi sütunun tamamı, noktalar değil:
nokta 9 pt ve ekranda otuz beş tane var.

Daha eskisi için ayrı bir kapı zaten vardı — "birikmiş borç". Yıllarca birikmiş
borcu gün gün işaretletmek anlamsız, şerit yedi gün veriyor, gerisi o alandan
giriliyor.

### İşaretleme penceresi

Kural tek cümle: **vakti girmemiş namaz işaretlenemez** (`PrayerMarking`). Öğle
vaktindeyken yatsıya "kıldım" demek kayıt tutmak değil, kaydı bozmak — geriye
dönük işaret bir gözlemi yazıyor, ileriye dönük işaret bir niyeti.

| Gün | Durum |
|---|---|
| Geçmiş | bütün vakitler açık |
| Bugün | yalnız vakti girmiş olanlar |
| Gelecek | tamamen kapalı |

Kapalı satır soluyor ve **sebebini yazıyor** ("vakti girmedi"): satırın neden
tepki vermediği başka hiçbir yerden anlaşılmıyor, kullanıcı bunu arıza sanardı.

Vakitler hesaplanamıyorsa (yüksek enlemde sabah/yatsı oluşmuyor) işaretlemeye
**izin veriliyor**. Hata yönü bilinçli: kullanıcıyı kendi kıldığı namazı
kaydetmekten alıkoymak, birkaç saat erken işaretlemesine izin vermekten daha kötü
bir sonuç.

Kural görünümde değil çekirdekte, çünkü saat de aynı kuralı uyguluyor: bilekteki
ızgarada vakti girmemiş hücre dokunulabilir değil. İki yerde ayrı yazılsaydı bir
gün ayrışırlardı.

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

Dosya biçimine alan eklenebiliyor: `PrayerLogSnapshot` kendi çözücüsünü yazıyor ve
eksik anahtarları varsayılana düşürüyor. Sentezlenen çözücü eksik anahtarı hata
sayıyor — `markedAt` alanını eklemek, eski dosyaların tamamını karantinaya
gönderirdi.

### Saatten işaretleme

Vakit bilekten de işaretlenebiliyor: saatteki ızgarada bir vakte dokunmak
kıldım / cemaatle / kılmadım / işareti kaldır seçimini açıyor.

**Kayıt telefonda kalıyor.** Saat ikinci bir kayıt dosyası tutmuyor; seri, kaza
borcu ve geçmiş tek yerde durduğu sürece "iki dosyayı birleştirme" sorunu hiç
doğmuyor. Akış bu yüzden bilerek asimetrik:

| Yön | API | Neden |
|---|---|---|
| saat → telefon (işaret) | `transferUserInfo` | kuyruklu ve teslimi garanti; telefondan uzakta konan işaret kaybolmuyor |
| telefon → saat (özet) | `updateApplicationContext` | yalnız **son** hâl anlamlı, bekleyen gönderimin üzerine yazması tam istenen şey |

Köprü (`WatchSyncController`) kök görünümde değil `EzanVaktiApp` içinde kuruluyor:
saatten gelen işaret uygulamayı arka planda uyandırıyor ve o anda çizilmiş bir
pencere olmayabiliyor.

#### Çakışma: sonra işaretlenen kazanır

Saat çevrimdışıyken konan işaret saatler sonra ulaşabiliyor. Sırayı geliş anı
belirlerse, o arada telefondan verilmiş daha yeni bir karar sessizce geri alınır.
Bu yüzden her işaret kondugu anı taşıyor (`PrayerMark.markedAt`) ve kayıt her
hücrenin son işaretlenme anını tutuyor (`PrayerLogSnapshot.markedAt`); gelen işaret
daha eskiyse reddediliyor. "İşareti kaldır" da bir karar sayılıyor — zaman damgası
işaret silinince de duruyor, yoksa kuyrukta bekleyen eski bir işaret onu geri
getirirdi.

Gün anahtarını **işareti koyan cihaz** üretiyor (`PrayerDay.key`). Telefonun gelen
işareti kendi takvimiyle yeniden yorumlaması, 23:55'te "yatsıyı kıldım" diyen
birinin kaydını ertesi güne düşürürdü.

#### Bekleyen işaret

Telefonun henüz onaylamadığı işaret saatte kuyrukta duruyor ve ızgarada **kesikli
kenarlıkla** görünüyor; onaylanınca kenarlık düz oluyor. Durum hücrenin içine değil
kenarlığına yazılıyor: 40 mm'de ad ve saat genişliği zaten tüketiyor, araya simge
sıkıştırmak adı kırpardı.

### Testler

```sh
swiftc -O EzanVakti/Core/Prayer.swift EzanVakti/Core/PrayerRecord.swift \
       EzanVakti/Core/PrayerSync.swift EzanVakti/Core/PrayerMarking.swift \
       EzanVakti/Core/RemainingTime.swift EzanVakti/Core/PrayerLogStore.swift \
       Tools/tests/main.swift -o /tmp/tests && /tmp/tests
```

68 kontrol: durum geçişleri, gün tamamlanması, seri kuralları, kaza aritmetiği
(çift sayma ve negatife düşme dahil), diske yazıp geri okuma, JSON'un okunabilirliği,
saatten gelen işaretin çakışma kuralları, işaretleme penceresinin sınırları,
kalan süre biçiminin kademeleri ve eski kayıt dosyasının okunabilmesi.

## Widget

Hedef `EzanVaktiWidgetExtension`, kaynakları `EzanVaktiWidget/` klasöründe.
Paylaşılan çekirdek dosyaları `membershipExceptions` ile bağlı; `Tools/check/targets.sh`
bu listeyi okuyup hedefi kendi dosya kümesiyle ayrıca derliyor.

### Neden hedef proje dosyasına elle eklenmedi

Widget ayrı bir uygulama uzantısı hedefi: gömme derleme fazı, hedef bağımlılığı,
`NSExtension` Info.plist anahtarları, ayrı yetkilendirme. Bunları elle yazılmış bir
`project.pbxproj`'a eklemek doğrulanamıyordu — geçerli bir plist üretmek derlenebilir
bir hedef üretmek demek değil, ve hata durumunda **çalışan proje bozulur**. Hedef
Xcode'un şablonuyla açıldı, sonra şablonun ürettiği `@main` dosyası silindi.

### Widget hedefine bağlı paylaşılan dosyalar

`Prayer.swift`, `PrayerCalculationParameters.swift`, `PrayerTimesCalculator.swift`,
`SolarMath.swift`, `SharedLocationStore.swift`, `PrayerActivityContent.swift`,
`PrayerActivityAttributes.swift` ve `Features/DesignSystem/` altındaki `Palette.swift`
ile `ScaledFont.swift`. Bağ `membershipExceptions` üzerinden; tek doğruluk kaynağı
`project.pbxproj`, denetim betiği de oradan okuyor.

App Group (`group.com.mahmud.ezanvakti`) dört hedefin hepsinde tanımlı.

### Kurulumda çıkılan tuzaklar

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

**Zemin `Palette`'ten geliyor, elle yazılmış kopyadan değil.** Bir süre widget'ta
ayrı bir degrade duruyordu ve değerleri uygulamanınkinden farklıydı:

| | Üst | Alt |
|---|---|---|
| Widget (elle yazılmış) | 0.07 / 0.09 / 0.20 | 0.14 / 0.16 / 0.31 |
| `Palette` (uygulama) | 0.04 / 0.05 / 0.13 | 0.10 / 0.10 / 0.21 |

Yani widget gözle görülür biçimde daha açık ve morumsuydu; yan yana durduklarında
ikisi aynı uygulamaya ait görünmüyordu. Kopyalanan bir rengin kaynağıyla ayrışması
an meselesi — artık tek kaynak var.

Ton **içinde bulunulan vakte göre** değişiyor, tıpkı uygulamada olduğu gibi
(`PrayerEntry.currentPrayer`): öğlen lacivert-mavi, akşam mor-kızıl. Çizelge zaten
vakit geçişlerinde girdi ürettiği için bu bedava geliyor. `Tools/render` ile günün
üç anında basılıp karşılaştırıldı.

### Ana ekranda kalan süre sözcüklü

Kare widget'ta sayaç 12 pt'den 19 pt'ye çıktı — ama düz büyütmek yetmiyordu.
Ham `Text(timerInterval:)` saat hanesi sıfırken onu düşürüyor, yani `6:21` altı
saat de olabilir altı dakika da; büyüdükçe o belirsizlik daha görünür oluyor.
Biçim `Text(_:style: .relative)`'e geçti: "5 sa. 2 dk." yazıyor, `timerInterval`
gibi kendi kendine ilerliyor (çizelgeye girdi eklemiyor), yalnız okunurluk
kazanılıyor. Komplikasyonlarda verilen kararın aynısı.

Orta widget de aynı biçime alındı; ikisi aynı ana ekranda yan yana durabiliyor ve
birinin "5 sa. 2 dk." diğerinin "5:02:31" demesi tek uygulamaya ait görünmüyordu.
Sözcüklü biçim daha uzun olduğu için oradaki sayaç alanı 62 pt'den 92 pt'ye
genişledi.

**Kilit ekranı aileleri değişmedi** — ayrı bir yüzey, ayrı bir bakış ve sistem
onları zaten tek renge tonluyor. Gerekirse ayrıca ele alınır.

**Denetlenmemiş:** `widgetRenderingMode` hiçbir yerde ele alınmıyor. iOS 18+
tonlu ana ekranda (`.accented`) ve StandBy'da (`.vibrant`) sistem widget'ı kendi
tekrenkli paletine çeviriyor; koyu bir degradenin o dönüşümde nasıl durduğu
cihazsız görülemiyor. Sorun çıkarsa çözümü o kiplerde zemini sisteme bırakmak
(`Color.clear`) — ama görmeden değiştirmek, düzeltmekten çok bozma riski taşıyor.
Kontrolü: ana ekranda boş yere basılı tut → Düzenle → Özelleştir → Renk tonu.

Kilit ekranı görünümleri **renk kullanmıyor**: sistem onları tek renge tonluyor,
altın vurgu orada kaybolurdu.

Geri sayım iOS widget'larında `Text(timerInterval:)`. Uygulamadaki elle kurulan
biçim ("1 sa 46 dk") **burada** kullanılamıyor: çizelge yalnızca vakit
geçişlerinde girdi ürettiği için durağan bir metin bir dakika içinde yanlış olurdu.

İki yer bu kısıtın dışında:

- **Saat uygulaması** — çizelge dakikada bir tik ürettiği için sözcüklü biçim
  elle kurulabiliyor ("Apple Watch → Kalan süre neden sözcüklü").
- **Saat komplikasyonları** — `Text(_:style:.relative)` kullanıyor; o da
  `timerInterval` gibi kendi kendine ilerliyor, yani girdi gerektirmiyor, ama
  sistemin diliyle "6 sa. 50 dk." yazıyor ("Komplikasyonlarda kalan süre").

### Ana ekranda kahraman: kalan süre

Kahraman alanda önce **vaktin saati** duruyordu (68 pt), kalan süre altında 16
pt'lik bir dipnottu. Gerekçesi "asıl aranan bilgi bu" idi ama ekranın tamamına
bakınca ters durduğu görülüyor: o saat **hemen aşağıdaki listede zaten yazıyor**
("İkindi 16:53"). Yani en büyük öğe bir tekrardı; listede hiç bulunmayan tek
bilgi — kalan süre — en küçüğüydü.

Şimdi tersi: `1ˢᵃ 46ᵈᵏ kaldı` kahraman (rakam 68 pt, birim 24 pt), vaktin saati
saat simgesiyle destek satırında. Ekranda tekrar kalmıyor ve satır tek cümle
olarak okunuyor.

Saat uygulamasıyla da aynı dil: biçim `RemainingTime`'dan geliyor, tek fark
telefonun eşiğin altında saniyeyi de göstermesi (saniyede bir zaten yenileniyor;
saatte saniyelik yeniden çizim pil demek, orada sistemin sayacına bırakılıyor).

**"16:53'te" yazılmadı.** Türkçede bulunma hâli eki saatin son okunan sayısına
göre değişiyor — "üçte" ama "yedide", "kırkta" ama "ellide". Sabit bir ek
zamanların yaklaşık yarısında yanlış olurdu; ekin doğrusu için sayı okuma tablosu
gerekiyor ve iki harf buna değmiyor. Saat simgesi aynı işi dilbilgisi olmadan
yapıyor.

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

Dört hedefin dördünde de var: `EzanVakti/`, `EzanVaktiWidget/`,
`EzanVaktiWatch Watch App/` ve `watch widget/` altında. 2024'ten beri App Store'a
gönderim için zorunlu ve **paket başına** gerekiyor — saat hedefleri de ayrı paket
olduğu için kendi bildirimlerini taşımak zorundalar.

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

Widget ve komplikasyon yalnızca App Group suite'ini kullandığı için onlarda sadece
`1C8F.1` var. Saat uygulamasında ikisi birden: paylaşılan konumu App Group'tan
okuyor (`1C8F.1`), telefonun henüz onaylamadığı işaret kuyruğunu ise kendi
alanında tutuyor (`CA92.1`).
Anahtar adının `NSPrivacyAccessedAPITypeReasons` olduğuna dikkat —
`NSPrivacyAccessedAPIReasons` değil.

### Veri toplama beyanı

`NSPrivacyTracking` = false, `NSPrivacyCollectedDataTypes` boş, üçüncü taraf
SDK yok.

Bu bir yorum barındırıyor: yurtdışında cami ararken koordinat Overpass'a
gönderiliyor. Apple'ın "toplama" tanımı, veriyi *isteği gerçek zamanlı
karşılamak için gerekenden uzun süre* cihaz dışında tutmak; Overpass isteği
anında işleyip bizim adımıza saklamıyor, dolayısıyla toplama sayılmıyor.
Yurt içinde cami verisi paketli olduğu için oraya hiçbir şey gönderilmiyor. Ancak
konum adının çözümü (`CLGeocoder`, watchOS 26+'da `MKReverseGeocodingRequest`) her
konum düzeltmesinde, her ülkede Apple'ın harita servisine gidiyor — izin metinleri
bunu açıkça söylüyor.

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

### Vakit girince etkinlik kalkmıyor (çözülmedi)

Geri sayım sıfırlandıktan sonra etkinlik kilit ekranında asılı kalıyor; ancak
kullanıcı uygulamayı bir daha açtığında (`endAll`) siliniyor.

Sebep `staleDate`'in sanılan işi yapmaması. SDK belgesi net: eskime tarihinde
`activityState` yalnız `.stale`'e dönüyor, etkinlik **ekrandan kaldırılmıyor**.
Standart bir etkinlik "uygulama, bir push bildirimi ya da kullanıcı sonlandırana
kadar, ya da azami süreyi aşana kadar" sürüyor. Sunucu yok, yani push yok;
uygulama da vakit girdiğinde çalışmıyor.

Denenip elenenler:

- **`ActivityStyle.transient`** — adı umut veriyor ama Dinamik Ada'ya özel:
  kullanıcı uygulamadan çıkınca ya da ekranı kilitleyince biten sunum.
- **`end(..., timestamp:)`** — `timestamp` ertelenmiş bitiş değil; belgesi
  "yükteki verinin üretildiği zaman" diyor, yalnızca sıralama için.
- **`request(..., start:)` ile birlikte bitiş** — böyle bir parametre yok
  (SDK arayüzünde doğrulandı).
- **Kurulur kurulmaz `end(dismissalPolicy: .after(prayerTime))`** — kâğıt
  üzerinde tek çözüm gibiydi ve denendi. **Cihazda etkinlik hiç görünmedi.**
  `end` etkinliği `.ended` durumuna geçiriyor; sonlandırılmış bir etkinlik
  Dinamik Ada'da sunulmuyor. Geri alındı — asılı kalmak, hiç görünmemekten iyi.

### Çözüm: arka plan temizliği

`BackgroundTasks` — Apple'ın `end` belgesinin gösterdiği yol ("uygulama önde ya da
arka plandayken"). `LiveActivityController.cleanupExpired()` vakti geçmiş
etkinlikleri `.immediate` ile sonlandırıyor, ardından elde kalanların en yakın
vaktine yeni bir `BGAppRefreshTaskRequest` bırakıyor. Zincir böyle sürüyor.

Kayıt `BGTaskScheduler.register` ile değil, sahnedeki
`.backgroundTask(.appRefresh(...))` değiştiricisiyle yapılıyor — uygulama yaşam
döngüsüne elle kanca takmak gerekmiyor. `LiveActivityController` bu yüzden
`RootView`'dan `EzanVaktiApp`'e taşındı: görev pencere çizilmeden çalışıyor,
denetleyici görünüme bağlı olsaydı tutunacak bir örnek bulamazdı.

Görev kimliği `Info.plist`'teki `BGTaskSchedulerPermittedIdentifiers` ile birebir
aynı olmak zorunda; ayrışırsa `submit` fırlatıyor.

**Garanti değil, en iyi çaba.** iOS bu görevleri fırsatçı çalıştırıyor:
`earliestBeginDate`'ten önce çalıştırmıyor ama sonrasında ne zaman çalıştıracağı
sistemin kararı. Çalışmazsa sonuç eskisiyle aynı — uygulama açılınca `endAll`
temizliyor — yani gerilemesi yok. `submit` başarısız olursa (en sık sebebi
kullanıcının "Arka Planda Yenileme"yi kapatmış olması) sebep `cleanupError`'da
duruyor ve bildirim ayarları sayfasında görünüyor; `lastError`'dan ayrı, çünkü o
etkinliğin hiç kurulamadığını söylüyor, bu yalnız geç kalkacağını.

### Doğrulanamayan

`ProgressView` macOS'ta `ImageRenderer` ile render edilmiyor (düz `value:`
alan sürümü de dahil — ortam kısıtı, API sorunu değil). Çubuğun cihazdaki
görünümü denetlenmedi. ActivityKit da iOS'a özel olduğu için
`PrayerActivityAttributes`, `PrayerLiveActivity` ve `LiveActivityController`
macOS tip denetiminin dışında.

Sonlandırılmış (`.ended`) bir etkinliğin `Text(timerInterval:)` sayacının
ilerlemeye devam edip etmediği de cihazsız doğrulanamıyor. Beklenen: devam
ediyor, çünkü sayaç içerik güncellemesine değil sistemin çizimine bağlı ve SDK
yalnızca `update` çağrılarının yok sayıldığını söylüyor. Donarsa belirti açık —
geri sayım kurulduğu değerde çakılı kalır — ve dönüşü tek satır.

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

Projede hazır olanlar: uygulama ikonu (hem iOS hem saat hedefinde, paketten
doğrulandı), gizlilik manifestoları, `ITSAppUsesNonExemptEncryption = false`
(ihracat uyumluluğu sorusunu atlatıyor), her iki platformda Türkçe konum izni
metni, açılış ekranı, dört hedefte de "Ezan Vakti" görünen adı.

İmzalama: `DEVELOPMENT_TEAM` **proje düzeyinde** tanımlı, dört hedef de onu miras
alıyor (hedef düzeyinde ayrıca yazılmıyor — tek yerde durması doğrusu). Dördünde
de `CODE_SIGN_STYLE = Automatic`, yani Xcode profilleri kendisi üretiyor.

App Group ücretli üyeliğe bağlı: portalda `group.com.mahmud.ezanvakti` bir kez
oluşturulup dört App ID'sinde de işaretlenmeli. Kurulmadığı sürece widget ve
komplikasyon paylaşılan konumu okuyamıyor, İstanbul'a düşüyor ve bunu ekranda
söylüyor.

### Gerçek arşiv denetimi

```sh
xcodebuild -project EzanVakti.xcodeproj -scheme EzanVakti -configuration Release \
           -destination 'generic/platform=iOS' -archivePath /tmp/EzanVakti.xcarchive archive
```

`Tools/check/targets.sh` yalnız tip denetimi yapıyor; hedef üyeliği, varlık
katalogları, plist'ler, imzalama ve gömülü uzantılar ancak gerçek arşivde
sınanıyor. Sonuç **ARCHIVE SUCCEEDED**, uyarısız; paket üçünü de taşıyor:

```
EzanVakti.app
EzanVakti.app/PlugIns/EzanVaktiWidgetExtension.appex
EzanVakti.app/Watch/EzanVaktiWatch Watch App.app
```

### Gönderim öncesi düzeltilenler

**iPad desteği kaldırıldı** (`TARGETED_DEVICE_FAMILY` `"1,2"` → `1`). Proje iPad'i
destekliyor görünüyordu ama dikey moda kilitliydi ve bütün düzenler iPhone'a göre
ölçülmüştü. Arşiv bunu uyarı olarak veriyordu ("All interface orientations must be
supported unless the app requires full screen") ve App Store tarafında **iPad ekran
görüntüsünü zorunlu** kılıyordu. İddiayı gerçeğe uydurmak hem uyarıyı hem o
zorunluluğu kaldırdı. Saat hedefleri zaten ailede 4 (watchOS).

**Görünen adlar.** Saat uygulaması `EzanVaktiWatch`, komplikasyon `watch widget`
diye görünüyordu — ikisi de Xcode'un iç hedef adı, ikisi de kullanıcıya çıkan
metin. Dördü de "Ezan Vakti" oldu.

**Saat dağıtım hedefi 26.5 → 10.0.** Bütün saat hedefini watchOS 26.5'e çiviliyen
tek bir satır vardı: `WatchLocationProvider`'daki `MKReverseGeocodingRequest`,
`#available` koruması olmadan. Yani en son güncellemeyi yüklememiş her saat,
yalnızca başlıktaki şehir adını çözen bir API yüzünden dışarıda kalıyordu.

Çağrı `#available(watchOS 26.0, *)` ile sarıldı, altına `CLGeocoder`'a düşülüyor
(telefon tarafı zaten onu kullanıyor). `Tools/check/targets.sh` artık saat
hedeflerini watchOS 10.0'a karşı derliyor ve tek hata vermiyor — yani 26.x isteyen
başka bir API yokmuş.

İki API arasında adın kaynağı farklı: MapKit ilçe/il ayrımı vermiyor, `CLGeocoder`
veriyor ve orada telefonla aynı tercih uygulanıyor (ilçe varsa ilçe). Kabul edilen
bir fark — vakit farkı komşu ilçeler arasında saniyeler mertebesinde ve ad yalnızca
başlıkta duruyor.

**Widget dağıtım hedefi 17.6 → 17.0.** Uzantı konağından yüksek sürüm istiyordu;
bu belgenin kendi kurulum talimatı da 17.0 diyor.

Xcode dışında yapılacaklar (App Store Connect):

- Apple Developer Program üyeliği (yıllık $99)
- App Store Connect kaydı ve bundle kimliğinin kaydı
- Ekran görüntüleri (6.9" ve 6.5" zorunlu)
- Açıklama, alt başlık, anahtar kelimeler, destek URL'si
- **Gizlilik politikası URL'si** — konum eriştiği için zorunlu
- Yaş sınırı anketi
- App Privacy beyanı (nutrition labels) — `PrivacyInfo.xcprivacy`'den ayrı,
  App Store Connect'te elle doldurulan bir form

Ezan sesi telifi bir engeldi; sesler pakette değil, o yüzden kalmadı. Ayrıntı:
"Bildirimler → Pakete konan sesler".

## Apple Watch

Saat uygulaması hedefi (`EzanVaktiWatch Watch App`) ve komplikasyon hedefi
(`watch widgetExtension`) kurulu. İkisi ayrı hedef olmak zorunda: komplikasyon
kendi `@main`'ini taşıyor, saat uygulamasıyla aynı hedefte olamaz. Ayrıntı
aşağıda, "Komplikasyon hedefi".

### Kapsam

- **Vakitler ekranı**: konum, sıradaki vakit, geri sayım, altında kaydırılan liste
- **Namaz takibi**: ızgaradaki vakte dokunarak kıldım / cemaatle / kılmadım
- **Komplikasyonlar**: dairesel, köşe, dikdörtgen, satır içi

**Vakitler telefondan gelmiyor.** Hesaplanabilir oldukları için saat kendi konumunu
alıp kendi hesaplıyor; telefon yanında olmasa da doğru çalışıyor. App Group iOS
uygulamasıyla saat arasında paylaşılmıyor (ayrı cihazlar), saatteki
`SharedLocationStore` yalnızca saat uygulaması ile komplikasyonu arasında.

Telefonla konuşulan tek konu **namaz işaretleri**: onların tek kaydı telefonda
duruyor ve hesaplanamıyorlar. Ayrıntı: "Namaz takibi & kaza → Saatten işaretleme".

### Kahraman alanı: büyük olan sayaç

Üstte "İKİNDİ 16:56", altında büyük geri sayım ve yanında "kaldı". Vaktin saati
**adına bitişik** duruyor, çünkü iki saat biçimli sayıyı yan yana koymak
karıştırıyordu: sayaç bir saatin altına inince `44:54` olup vaktin saatiyle
(`16:56`) aynı şekle bürünüyor.

İlk sürümde ad ile saatin arasında `Spacer` vardı, ikisi iki kenara itiliyordu —
ve bağ tam da bu yüzden kopuyordu: sağ kenarda tek başına duran `16:56` neyin
saati olduğunu söylemiyor, ekrandaki üçüncü etiketsiz sayı oluyordu. Bitişik
yazılınca üst satır tek bir bilgi olarak okunuyor.

Büyük sayının yanındaki "kaldı" da aynı sorunun diğer yarısı: etiketsiz bırakılan
bir sayı tek başına bir vaktin saati gibi okunabiliyor. Sözcük telefondaki geri
sayımın yanında da duruyor (`remainingCaption`) ve satır içi olduğu için 40 mm'de
dikey yer tutmuyor.

### Kalan süre neden sözcüklü

Biçim `RemainingTime`'da ve **telefonla ortak** — iki ekran aynı dili konuşuyor.
Sayacın kendisi de ham `Text(timerInterval:)` değil. Sistemin biçimi saat hanesi
sıfırken onu düşürüyor:

| Gerçekte kalan | Sistemin bastığı |
|---|---|
| 6 dk 21 sn | `6:21` |
| 6 sa 21 dk | `6:21:34` |

Yani `6:21` ile `6:21:34` aynı ekranda birbirinin yerine geçebiliyor ve vakte altı
dakika kalan bir sayaç "altı saat var" diye okunabiliyor. Yanına "kaldı" yazmak
bunu çözmüyor; sorun sayının kendisinde. Denemede bu yanlış okuma gerçekten oldu.

Bu yüzden üç aralık var:

| Kalan | Gösterim | Neden |
|---|---|---|
| ≥ 1 saat | `10ˢᵃ 46ᵈᵏ` | saniye gürültü, birim zorunlu |
| 10 dk – 1 saat | `47ᵈᵏ` | tek birim, tereddüt yok |
| < 10 dk | `6:21` (saniyeli) | saniye artık anlamlı, akan hane biçimi kendisi anlatıyor |

Sayı büyük, birim küçük: düz "6 sa 21 dk" 30 pt'de 40 mm'ye sığmıyor, iki kademeli
hâli yarı yer kaplıyor — en geniş durum (`10ˢᵃ 46ᵈᵏ kaldı`, kış gecesi yatsıdan
imsağa) `Tools/render` ile 40 mm'de ölçüldü.

**Pil maliyeti yok.** Sözcüklü biçim dakikada bir yeniden çizim istiyor ama saatte
çizelge (`PrayerBoundarySchedule`) zaten dakikalık tik üretiyor. Son 10 dakikada
`timerInterval`'e dönülüyor: saniyenin gerçekten önemli olduğu tek pencerede sayaç
yine sistem tarafından sürülüyor, uygulama arka planda dururken de doğru kalıyor.

Kısaltmalar yalnız ekran için: VoiceOver `RemainingReadout.spoken` alanını okuyor
("10 saat 46 dakika kaldı"), yoksa "sa" ve "dk" harf harf ya da yanlış okunuyordu.

Sayaç `Text(timerInterval:)`; uygulama arka planda dururken de kendi kendine
ilerliyor. Kış gecesi imsağa 10+ saat kaldığında sekiz haneye çıkıyor
(`10:41:34`) — 40 mm'de bile sığdığı ölçüldü, ayrıca `minimumScaleFactor`
konuldu.

### Ekran düzeni: neden iki sütun

Altı vakit alt alta en küçük ekrana (40 mm, durum çubuğu düşünce ~167 pt)
sığmıyordu; liste iki sütuna katlandı ve gün tamamı kaydırmadan görünüyor.

Ölçüler (punto, satır yüksekliği, kahraman saatin boyu) tek sabit set değil:
`GeometryReader`'ın bildirdiği **yüksekliğe** göre üç kademe var — 40 mm'de
kompakt (154 pt), 41 mm'de orta (174 pt), 45 mm ve üstünde ferah (204 pt).
Karar genişliğe bakmıyor: ekran boyu ile durum çubuğu payı modelden modele
değiştiği için genişlik ancak dolaylı bir gösterge, yükseklik ise gerçekten
kalan yeri söylüyor. Genişliğe bakan ilk sürümde 40 mm kenar boşluksuz gelince
orta kademeye düşüp taşma sınırına geliyordu.

`ScrollView` yalnızca erişilebilirlik puntolarında devrede; normal puntolarda
kabuk yok, çünkü ScrollView sonsuz yükseklik önerip `GeometryReader`'ın gerçek
yeri görmesini engelliyor.

İki tuzak, ikisi de render denetiminde yakalandı:

- Vakit saatlerinde `lineLimit(1)` yoktu; dar ekranda `04:4 / 2` diye ikiye
  bölünüp satır yüksekliğini katlıyor, içeriği 45 pt şişiriyordu.
- İsimle saat arasındaki `Spacer`, ismi yeri paylaşmaya zorlayıp 40 mm'de
  `Akşa…` diye kırpıyordu. Spacer kalktı, artan genişlik doğrudan isme verildi.

### Kıble neden yok

Bileği kıbleye çevirmek için kolu tuhaf bir açıda sabitlemek gerekiyor ve pusula
bilekte manyetik olarak daha az güvenilir. Daha önemlisi kıble **tekrarlanan bir
iş değil** — bir konumda bir kez bulunuyor. Saatin değeri bir bakışta alınan
tekrarlı bilgide; kıble oraya uymuyor, telefonda kalıyor.

### Namaz takibi: işaret bilekte, kayıt telefonda

Izgaradaki bir vakte dokunmak seçim ekranını açıyor. İşaret `WatchConnectivity`
ile telefona gidiyor, kayıt orada tutuluyor — saatte ikinci bir kayıt dosyası
yok, dolayısıyla birleştirilecek iki dosya da yok.

Telefondaki "dokundukça sıradaki duruma geç" düzeni saate taşınmadı: orada satır
geniş ve yanlış duruma geçmek bir dokunuş uzakta; bilekte hedef küçük, dokunuş
çoğu zaman yürürken oluyor ve döngüde yapılan hatayı düzeltmek üç dokunuş daha
demek. Açık seçim ekranı, ekran zaten dokunuşla açıldığı için pahalı değil.

Güneş dokunulabilir değil — namaz vakti değil, sabahın çıkış anı.

Çakışma kuralları, kuyruk ve kesikli kenarlığın anlamı için bkz.
"Namaz takibi & kaza → Saatten işaretleme".

### Saat hedefine bağlı paylaşılan dosyalar

`Prayer.swift`, `PrayerCalculationParameters.swift`, `PrayerTimesCalculator.swift`,
`SolarMath.swift`, `SharedLocationStore.swift`, takip için `PrayerRecord.swift` ile
`PrayerSync.swift`, ve `Features/DesignSystem/` altındaki `Palette.swift`,
`ScaledFont.swift`, `StatusStyle.swift`. `PrayerLogStore` **bilerek yok**: kaydın
sahibi telefon.

### Telefondaki `LocationProvider` neden kullanılmadı

O sınıf pusula yönü, elle konum seçimi ve App Group paylaşımı taşıyor; saatte
hiçbiri gerekmiyor ve pusula API'lerinin watchOS'taki durumu ayrı bir
belirsizlik. Saat için tek işi olan ayrı bir sağlayıcı yazıldı.

### Komplikasyonlar

Dört aile destekleniyor. Zaman çizelgesi telefondaki widget ile aynı mantıkta:
vakitler belirlenimci olduğu için girdiler bir gün ileriye baştan üretiliyor ve
yalnızca vakit geçişlerinde konuyor — geri sayımlar `timerInterval` ile kendi
kendine ilerlediği için dakikalık girdiye gerek yok.

| Aile | Ne gösteriyor |
| --- | --- |
| `accessoryCorner` | Kavisli kenarda **kalan süre**, köşede vaktin simgesi |
| `accessoryCircular` | İlerleme halkası + simge + vaktin saati |
| `accessoryRectangular` | Vakit adı, saati, kalan süre, ilerleme çubuğu |
| `accessoryInline` | Tek satır: vakit adı + kalan süre |

Köşede kalan süre neden `widgetLabel`'da: köşenin iç alanı dört-beş karakter
alıyor. Kavisli kenarda yer var, hangi vakit olduğunu da içerideki simge söylüyor.

Köşedeki simge `frame(maxWidth:maxHeight:)` ile alanı kaplayıp ortalanıyor;
yalnız asıl boyutunda bırakılınca yerleşim kapsayıcının varsayılan hizasına
kalıyor ve kayık duruyordu. Puntosu 20 — kavisli kenarda yalnız süre yazdığı
için hangi vakit olduğunu söyleyen **tek** işaret o, alanın yarısında kalması az.

**`accessoryCorner` render edilemiyor.** `widgetLabel` watchOS'a özel, macOS'ta
yok; `Tools/render` bu aileyi basamıyor. Dört aile içinde gözle denetlenemeyen
tek yer burası, değişiklikleri cihazda kontrol etmek gerekiyor.

### Komplikasyonlarda kalan süre

Ham geri sayım `6:50:10` diye çıkıyordu: saniyesi yedi saat ötedeki bir vakit
için gürültü, üç parçalı hâli de bir bakışta okunmuyor. Durağan metin ise yasak —
çizelge yalnız vakit geçişlerinde girdi üretiyor.

Çıkış `Text(_:style: .relative)`. `timerInterval` gibi kendi kendine ilerliyor
(girdi gerektirmiyor) ama sistemin diliyle yazıyor:

| Biçem | Türkçe çıktı |
|---|---|
| `timerInterval` | `6:50:10` |
| `.relative` | `6 sa. 50 dk.` |
| `.offset` | `−6 saat` — kaba ve eksi işaretli, elendi |

Aile aile karar verildi, hepsine aynı şey uymuyor:

- **Dikdörtgen ve tek satır** → `.relative`. "kaldı" sözcüğü ikisinde de
  düşürüldü: birimler zaten süre olduğunu söylüyor ve dar yuvada kırpılacak ilk
  şey o olurdu.
- **Köşe** → `.relative`, kavisli kenarda yer var.
- **Daire** → ne geri sayım ne `.relative`, **vaktin saati**. Çemberin iç alanı
  ~30 pt; `6:50:10` 11 pt'de ~50 pt istiyor, `6 sa. 50 dk.` ~65 pt. Küçültme
  çarpanıyla bile okunmuyor. "Ne kadar kaldı"yı zaten halka söylüyor, içerisi
  "ne zaman"ı alıyor.

Uygulamanın kendi biçimiyle küçük bir fark kalıyor: `.relative` bir saatin
altında saniyeyi de yazıyor ("46 dk. 59 sn."), uygulama ise 10 dakikaya kadar
yalnız dakika gösteriyor. Birim seçimi sisteme ait, dışarıdan ayarlanamıyor —
alternatifi durağan metin, o da komplikasyonda kullanılamıyor.

**Yerel bağımlılığı:** `.relative` cihazın diline göre yazıyor. Sistem dili
Türkçe değilse komplikasyon "6 hr, 50 min" der; uygulamanın kendi biçimi Türkçe
kalır. Kabul edilen bir tutarsızlık — karşılığı, kadranda hiç okunmayan bir
sayı.

Komplikasyonlar sistem tarafından tek renge tonlandığı için altın vurgu
kullanılmıyor.

### Dikdörtgende alt/üst boşluk

İki ayrı kaynağı vardı, ikisi de düzeltildi.

**Sistem payı.** WidgetKit her aileye varsayılan bir içerik payı uyguluyor;
dikdörtgende bu, altta ve üstte ölü bant olarak görünüyor. Doğru kapatma yolu
yapılandırmadaki `contentMarginsDisabled()`. Ayar bütün ailelere birden
uygulandığı için pay `WatchComplicationEntryView`'de aile aile geri veriliyor:
daire, köşe ve tek satır tam payı alıyor, dikdörtgen yalnız yatay payı.
Sistemin ne uygulayacağı `@Environment(\.widgetContentMargins)` ile okunabiliyor
— kapatmak bu değeri silmiyor.

**Nefes payı yuvaya bırakılıyor.** Üç satır sabit aralıkla (2 pt) üst üste
duruyor ve blok dikey olarak ortalanıyor. Boşluk böylece yuvaya orantılı: 56 pt
yükseklikte alta ve üste ~7 pt düşüyor, 48 pt'de ~3 pt, dar uçta kendiliğinden
sıfıra iniyor. Sabit bir dolgu yazmak dar kadranda tam da sığması gereken yeri
çalardı.

Denenip vazgeçilen **iki** yol var:

- `.padding(.vertical, -15)` — negatif pay payı kaldırmıyor, içeriği yuvadan
  taşırıyor ve WidgetKit taşanı kırpıyor. 48 pt yükseklikte üst satır ikiye
  bölünüyordu, 56 pt'de bölünmüyordu; yuva saat modeline göre değiştiği için
  tek bir sayı bütün cihazlarda doğru olamaz.
- Satırları `Spacer` ile kenarlara yaslamak — boşluk kenardan gidiyor ama bu
  sefer içerik yuvanın kenarına yapışıyor, komplikasyon sıkışık görünüyor.
  Boşluğu yok etmek değil, ölçüsünü yuvaya bırakmak doğru.

Satır içi hiyerarşi de düzeltildi: vaktin **adı birincil**, saati ikincil. Üçü
de aynı tonda dururken üst satır tek bir gri şerit gibi okunuyordu.

**Render tuzağı:** `ProgressView(timerInterval:)` macOS'ta kalın sarı bant
basıyor ve bütün yüksekliği yiyor — bu hâliyle dikey dağılım hakkında hiçbir şey
söylemiyor, üstelik "boşluk yok" diye yanlış okutuyor. `Tools/render` harness'ında
çubuğun yerine watchOS'taki gerçek kalınlığında (~4 pt) bir şerit konarak
bakıldı. Kırpılma denetimi için vekile gerek yok, dikey ritim için şart.

### Komplikasyon hedefi

Hedef `watch widgetExtension`, kaynakları `watch widget/` klasöründe. Paylaşılan
altı dosya `membershipExceptions` ile bağlandı — beşi `EzanVakti/Core`'dan
(`Prayer`, `PrayerCalculationParameters`, `PrayerTimesCalculator`,
`SharedLocationStore`, `SolarMath`), biri `EzanVaktiWidget`'ten
(`PrayerWidgetEntry`). `Palette` ile `ScaledFont` gerekmiyor: komplikasyonlar
sistemce tonlandığı için altın vurgu kullanılmıyor (ölçüldü).

Konum paylaşımı için **App Group yetkisi iki saat hedefine de gerekiyor**:
saat uygulaması `SharedLocationStore`'a yazıyor, komplikasyon okuyor. Yetki
olmasa derleme yine geçerdi ama `UserDefaults(suiteName:)` boş dönüp
komplikasyon hep İstanbul gösterirdi — sessiz bir hata.
(`EzanVaktiWatch.entitlements`, `WatchWidgetExtension.entitlements`)

Konum izni metni (`NSLocationWhenInUseUsageDescription`) ve gizlilik bildirimi
saat hedeflerine de eklendi: saat kendi konumunu kendisi aldığı için iOS hedefinin
metnini devralmıyor, izni kendi adına sorması gerekiyor.

### Denetimin kaçırdığı hata: MemberImportVisibility

`WatchComplicationViews.swift` `widgetLabel` kullanıyordu ama `WidgetKit`'i
import etmiyordu. Aynı modüldeki başka bir dosya import ettiği için `swiftc`
varsayılan ayarla sorun görmüyor, Xcode ise patlıyordu — proje
`SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` ile derliyor.
`Tools/check/targets.sh` artık aynı bayrağı açıyor.

## v1 kapsamı

Tamam: vakitler ekranı, bildirimler, kıble, imsakiye, namaz takibi & kaza sayacı, widget.
