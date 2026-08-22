# Temkin kalibrasyonu

Diyanet'in yayınladığı vakitler astronomik hesaba "temkin" payı ekliyor.
`PrayerCalculationParameters.diyanet` içindeki düzeltmeler bu payı modelliyor ve
tahminle değil ölçümle türetildi.

## Yöntem

1. `ezanvakti.emushaf.net` aynasından 15 ilin merkez ilçesi için aylık Diyanet
   takvimi çekilir (ayna `namazvakti.diyanet.gov.tr`'yi yansıtıyor).
2. Aynı illerin koordinatları Nominatim'den alınır (saniyede 1 istek).
3. `Tools/calibrate` çıplak astronomik vakitleri (`.astronomical`) hesaplar.
4. Fark alınıp vakit başına medyan bulunur.

İller bilerek uçlardan seçildi: Edirne (en batı), Hakkari/Van (en doğu),
Sinop/Samsun (kuzey), Antalya (güney), Erzurum (yüksek rakım).

## Son ölçüm (Ağustos 2026, 15 il)

Gereken düzeltme, iller arası yayılım:

| Vakit | Yayılım | Medyan |
|---|---|---|
| İmsak | 4 dk | 0 |
| Güneş | 3 dk | −7 |
| Öğle | 3 dk | +6 |
| İkindi | 2 dk | +5 |
| Akşam | 3 dk | +9 |
| Yatsı | 2 dk | +2 |

Medyan değerler uygulandığında: **en kötü 2 dk**, ortalama sapma 0.56 dk,
karşılaştırmaların %92'si 1 dk içinde.

Kalan uçlar (Hakkari, Samsun, Sinop, Van) temkinden değil koordinat farkından:
Diyanet her ilçe için kendi referans noktasını kullanıyor ve yayınlamıyor.
Hesaplamaya dayalı yaklaşımda pratik taban bu.
