import SwiftUI

struct TrackingView: View {
    let log: PrayerLogStore

    @State private var isEditingQada = false

    var body: some View {
        ZStack {
            Palette.background(for: nil)
                .ignoresSafeArea()

            ScrollView {
                // Zamanı dakikada bir tazeliyor: uygulama gece yarısını geçerek
                // açık kalırsa dokunuşlar dünün gününe yazılmasın.
                TimelineView(.everyMinute) { context in
                    TrackingContent(log: log,
                                    now: context.date,
                                    onEditQada: { isEditingQada = true })
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .sheet(isPresented: $isEditingQada) {
            QadaSetupView(log: log)
        }
    }
}

/// Kaydırma kabuğundan ayrı tutuluyor: `ImageRenderer` ScrollView içeriğini
/// basmıyor, bu haliyle ekran Xcode'suz görsel olarak kontrol edilebiliyor.
struct TrackingContent: View {
    let log: PrayerLogStore
    /// Dışarıdan veriliyor ki yapı kurulurken sabitlenmesin; varsayılanı olması
    /// `ImageRenderer` ile tek satırda kurmayı bozmuyor.
    var now: Date = Date()
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
                    let status = log.status(for: prayer, on: now)
                    Button {
                        log.advanceStatus(for: prayer, on: now)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: prayer.symbolName)
                                .scaledFont(15)
                                .frame(width: 22)
                                .foregroundStyle(.white.opacity(0.5))
                            Text(prayer.title)
                                .foregroundStyle(.white.opacity(0.9))
                            Spacer()
                            Text(status.title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(status == .unmarked ? .white.opacity(0.35) : status.tint)
                            Image(systemName: status.symbolName)
                                .scaledFont(19)
                                .foregroundStyle(status.tint)
                        }
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // Dokundukça durum değiştiği için etiket-değer-ipucu üçlüsü
                    // gerekiyor: ne olduğu, hangi durumda olduğu, ne olacağı.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(prayer.title)
                    .accessibilityValue(status == .unmarked ? "işaretlenmedi" : status.title)
                    .accessibilityHint("Sıradaki duruma geçmek için dokun: \(status.next.title)")
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
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(formatter.string(from: day)), \(log.performedCount(on: day)) / 5 kılındı")
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
        if let message = log.lastReadError ?? log.lastWriteError {
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
