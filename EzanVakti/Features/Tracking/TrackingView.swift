import SwiftUI

struct TrackingView: View {
    let log: PrayerLogStore
    /// Vakitler işaretleme penceresi için gerekiyor: vakti girmemiş namaz
    /// işaretlenemiyor, o da konuma bağlı.
    let location: LocationProvider
    /// Saatle eşleşme sessizce bozulursa kullanıcı bunu ancak bilekten
    /// işaretlediği vakitleri burada bulamayarak anlar; hata görünür duruyor.
    var watchSyncError: String?

    @State private var isEditingQada = false
    /// Açık gün sayfası. `Date` kendi başına `Identifiable` değil, sarmalanıyor.
    @State private var editingDay: TrackedDay?

    /// `.autoupdatingCurrent`: uçakla dilim değiştirmek bu uygulamanın ana
    /// senaryosu; gün sınırı da işaret de yerel güne göre.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    private var coordinate: Coordinate {
        if case .resolved(let coordinate, _) = location.state { return coordinate }
        return .istanbul
    }

    private func times(for day: Date) -> DailyPrayerTimes? {
        PrayerTimesCalculator(coordinate: coordinate, parameters: .diyanet)
            .times(for: day, in: calendar.timeZone)
    }

    var body: some View {
        ZStack {
            Palette.background(for: nil)
                .ignoresSafeArea()

            ScrollView {
                // Zamanı dakikada bir tazeliyor: uygulama gece yarısını geçerek
                // açık kalırsa dokunuşlar dünün gününe yazılmasın. Aynı tik
                // işaretleme penceresini de ilerletiyor — vakit girince satır
                // bir dakika içinde açılıyor.
                TimelineView(.everyMinute) { context in
                    TrackingContent(log: log,
                                    now: context.date,
                                    todayTimes: times(for: context.date),
                                    calendar: calendar,
                                    watchSyncError: watchSyncError,
                                    onSelectDay: { editingDay = TrackedDay(date: $0) },
                                    onEditQada: { isEditingQada = true })
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .sheet(isPresented: $isEditingQada) {
            QadaSetupView(log: log)
        }
        .sheet(item: $editingDay) { day in
            DayDetailView(log: log, day: day.date, times: times(for: day.date),
                          now: Date(), calendar: calendar)
        }
    }
}

/// `sheet(item:)` `Identifiable` istiyor; gün anahtarı zaten benzersiz.
struct TrackedDay: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSinceReferenceDate }
}

/// Kaydırma kabuğundan ayrı tutuluyor: `ImageRenderer` ScrollView içeriğini
/// basmıyor, bu haliyle ekran Xcode'suz görsel olarak kontrol edilebiliyor.
struct TrackingContent: View {
    let log: PrayerLogStore
    /// Dışarıdan veriliyor ki yapı kurulurken sabitlenmesin; varsayılanı olması
    /// `ImageRenderer` ile tek satırda kurmayı bozmuyor.
    var now: Date = Date()
    /// Bugünün vakitleri; vakti girmemiş namaz işaretlenemiyor. Varsayılan nil
    /// olduğu için `ImageRenderer` ile tek satırda kurmak hâlâ mümkün — o
    /// durumda bütün satırlar açık, `PrayerMarking` bunu böyle tanımlıyor.
    var todayTimes: DailyPrayerTimes?
    var calendar: Calendar = .current
    var watchSyncError: String?
    var onSelectDay: (Date) -> Void = { _ in }
    var onEditQada: () -> Void = {}

    var body: some View {
        VStack(spacing: 20) {
            storageNotice
            streakHeader
            todaySection
            weekSection
            qadaSection
        }
    }

    // MARK: - Seri

    private var streakHeader: some View {
        let streak = log.currentStreak(today: now)
        return VStack(spacing: 4) {
            Text("\(streak)")
                .scaledFont(46, weight: .semibold, design: .rounded)
                .foregroundStyle(streak == 0 ? .white.opacity(0.45) : Palette.accent)
                .contentTransition(.numericText())
            Text(streak == 0 ? "seri yok" : "günlük seri")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.top, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(streak == 0 ? "Seri yok" : "\(streak) günlük seri")
    }

    // MARK: - Bugün

    private var todaySection: some View {
        card(title: "Bugün", trailing: "\(log.performedCount(on: now))/5") {
            VStack(spacing: 0) {
                ForEach(PrayerLogStore.trackedPrayers) { prayer in
                    PrayerStatusRow(
                        prayer: prayer,
                        status: log.status(for: prayer, on: now),
                        isMarkable: PrayerMarking.isMarkable(prayer, on: now, times: todayTimes,
                                                             now: now, calendar: calendar),
                        onAdvance: { log.advanceStatus(for: prayer, on: now) }
                    )
                }
            }
        }
    }

    // MARK: - Son 7 gün

    private var weekSection: some View {
        let days = log.recentDays(count: 7, ending: now)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        // Tek harf Türkçe'de ayırt etmiyor: Pazar/Pazartesi/Perşembe hepsi "P".
        formatter.dateFormat = "EEEEEE"

        return card(title: "Son 7 gün") {
            HStack(alignment: .top, spacing: 0) {
                ForEach(days, id: \.self) { day in
                    // Dokunma hedefi sütunun tamamı, noktalar değil: nokta 9 pt
                    // ve ekranda otuz beş tane var.
                    Button { onSelectDay(day) } label: {
                        VStack(spacing: 6) {
                            ForEach(PrayerLogStore.trackedPrayers) { prayer in
                                Circle()
                                    .fill(log.status(for: prayer, on: day).tint)
                                    .frame(width: 9, height: 9)
                            }
                            Text(formatter.string(from: day))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.45))
                                .padding(.top, 2)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(formatter.string(from: day)), \(log.performedCount(on: day)) / 5 kılındı")
                    .accessibilityHint("Bu günü işaretlemek için dokun")
                }
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Kaza

    private var qadaSection: some View {
        card(title: "Kaza", trailing: "toplam \(log.totalQada)") {
            VStack(spacing: 0) {
                ForEach(PrayerLogStore.trackedPrayers) { prayer in
                    let balance = log.qadaBalance(for: prayer)
                    HStack(spacing: 12) {
                        Text(prayer.title)
                            .foregroundStyle(.white.opacity(balance == 0 ? 0.4 : 0.9))
                        Spacer()
                        Text("\(balance)")
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(balance == 0 ? .white.opacity(0.3) : .white)
                        Button {
                            log.payQada(for: prayer)
                        } label: {
                            Text("Kıldım")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(balance == 0 ? .white.opacity(0.25) : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background {
                                    Capsule().fill(balance == 0
                                        ? Color.white.opacity(0.06)
                                        : Color(red: 0.30, green: 0.78, blue: 0.45).opacity(0.85))
                                }
                        }
                        .buttonStyle(.plain)
                        .disabled(balance == 0)
                        .accessibilityLabel("\(prayer.title) kazası kıldım")
                    }
                    .padding(.vertical, 9)
                    .accessibilityElement(children: .contain)
                }

                Button {
                    onEditQada()
                } label: {
                    Label("Birikmiş borcu düzenle", systemImage: "slider.horizontal.3")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Kayıt uyarısı

    /// Kayıt dosyası okunamadıysa ya da yazılamıyorsa kullanıcı bunu bilmeli:
    /// aylarca birikmiş takip ve kaza borcu bu dosyada duruyor ve sessizce
    /// kaybolması, kaybolduğunun fark edilmemesi demek.
    @ViewBuilder
    private var storageNotice: some View {
        if let message = log.lastReadError ?? log.lastWriteError ?? watchSyncError {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.orange.opacity(0.12))
                }
        }
    }

    // MARK: - Ortak kart

    private func card<Content: View>(
        title: String,
        trailing: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: title, size: 11, tracking: 1.4)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(.black.opacity(0.2))
        }
    }
}
