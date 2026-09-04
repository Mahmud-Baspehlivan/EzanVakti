import Foundation

/// Bir namazın işaretlenebilir olup olmadığı.
///
/// Kural tek cümle: **vakti girmemiş namaz işaretlenemez.** Öğle vaktindeyken
/// yatsıya "kıldım" demek kayıt tutmak değil, kaydı bozmak — geriye dönük
/// işaret bir gözlemi yazıyor, ileriye dönük işaret bir niyeti.
///
/// Geçmiş günlerde bütün vakitler girmiş olduğu için kural yalnız bugünü
/// sınırlıyor. Uygulamanın açılmadığı günlerin sonsuza kadar çözümsüz kalmaması
/// bu yüzden mümkün: kayıt geriye yazılabiliyor, ileriye yazılamıyor.
///
/// Görünümde değil çekirdekte: telefon ile saat aynı kuralı uygulamak zorunda,
/// iki yerde ayrı yazılırsa bir gün ayrışırlar.
enum PrayerMarking {
    /// - Parameters:
    ///   - times: `day` gününün vakitleri. Hesaplanamıyorsa `nil`.
    static func isMarkable(_ prayer: Prayer, on day: Date, times: DailyPrayerTimes?,
                           now: Date, calendar: Calendar) -> Bool {
        let today = calendar.startOfDay(for: now)
        let target = calendar.startOfDay(for: day)

        if target < today { return true }
        if target > today { return false }

        // Bugün: yalnız vakti girmiş olanlar.
        //
        // Vakitler hesaplanamıyorsa (yüksek enlemde sabah/yatsı oluşmuyor)
        // izin veriliyor. Hata yönü bilinçli: kullanıcıyı kendi kıldığı namazı
        // kaydetmekten alıkoymak, birkaç saat erken işaretlemesine izin
        // vermekten daha kötü bir sonuç.
        guard let times else { return true }
        return times[prayer] <= now
    }
}
