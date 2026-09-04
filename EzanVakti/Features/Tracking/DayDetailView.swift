import SwiftUI

/// Geçmiş bir günün namazlarını işaretleme sayfası.
///
/// Neden ayrı sayfa: hafta şeridindeki noktalar dokunma hedefi olamıyor — 9 pt
/// ve ekranda otuz beş tane var. Sütuna dokunmak günü açıyor, gün de "Bugün"
/// kartındaki satırların aynısını gösteriyor.
struct DayDetailView: View {
    let log: PrayerLogStore
    let day: Date
    /// Günün vakitleri; hesaplanamıyorsa nil ve o gün serbest işaretlenebiliyor.
    let times: DailyPrayerTimes?
    var now: Date = Date()
    var calendar: Calendar = .current

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(PrayerLogStore.trackedPrayers) { prayer in
                        PrayerStatusRow(
                            prayer: prayer,
                            status: log.status(for: prayer, on: day),
                            isMarkable: PrayerMarking.isMarkable(prayer, on: day, times: times,
                                                                 now: now, calendar: calendar),
                            onAdvance: { log.advanceStatus(for: prayer, on: day) }
                        )
                    }
                } footer: {
                    Text("Geçmiş günler işaretlenebilir; uygulamayı açmadığın bir gün böylece çözümsüz kalmıyor. Vakti henüz girmemiş namazlar kapalı.")
                }
            }
            .navigationTitle(Self.title(for: day, calendar: calendar))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti") { dismiss() }
                }
            }
        }
    }

    /// "24 Ağustos Pazartesi" — bugün ise ayrıca söyleniyor, sayfanın hangi
    /// güne yazdığı tek bakışta belli olsun.
    static func title(for day: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "d MMMM EEEE"
        let text = formatter.string(from: day)
        return calendar.isDateInToday(day) ? "Bugün · \(text)" : text
    }
}
