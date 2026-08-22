import SwiftUI

/// Aylık vakit çizelgesi. Başlık kaydırma dışında sabit kaldığı için sütun
/// adları hep görünür; tablo bölümü ayrı tutulup kaydırma kabuğuna veriliyor.
struct ImsakiyeHeader: View {
    let viewModel: ImsakiyeViewModel
    var onStep: (Int) -> Void = { _ in }
    var onToday: () -> Void = {}

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                SectionLabel(text: "İmsakiye")
                Spacer()
                if !viewModel.isShowingCurrentMonth {
                    Button("Bugün", action: onToday)
                        .scaledFont(12, weight: .semibold)
                        .foregroundStyle(Palette.accent)
                        .buttonStyle(.plain)
                }
            }

            HStack(spacing: 0) {
                stepButton(-1, "chevron.left")
                VStack(spacing: 2) {
                    Text(viewModel.monthTitle)
                        .scaledFont(20, weight: .semibold)
                        .foregroundStyle(.white)
                    Text(viewModel.hijriSpan)
                        .scaledFont(11)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                stepButton(1, "chevron.right")
            }

            Text(viewModel.locationName)
                .scaledFont(12)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func stepButton(_ delta: Int, _ symbol: String) -> some View {
        Button { onStep(delta) } label: {
            Image(systemName: symbol)
                .scaledFont(15, weight: .semibold)
                .foregroundStyle(.white.opacity(0.65))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(delta < 0 ? "Önceki ay" : "Sonraki ay")
    }
}

/// Sütun genişlikleri sabit başlık ile kayan satırlar arasında paylaşılıyor;
/// iki yerde ayrı ayrı tanımlanırsa hizalama sessizce kayar.
enum ImsakiyeLayout {
    static let dateWidth: CGFloat = 46
}

/// Kaydırma alanının dışında duruyor ki satırlar akarken sütun adları görünür kalsın.
struct ImsakiyeColumnHeader: View {
    let viewModel: ImsakiyeViewModel

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Erişilebilirlik boyutlarında tablo blok düzenine geçiyor; sütun
        // başlığının anlamı kalmıyor.
        if !typeSize.isAccessibilitySize { columns }
    }

    private var columns: some View {
        HStack(spacing: 0) {
            // Yükseklik bilerek sabitlendi: yalnız genişlik verilen Color.clear
            // dikeyde açgözlü davranıp başlığı ekranın yarısı kadar şişiriyordu.
            Color.clear.frame(width: ImsakiyeLayout.dateWidth, height: 1)
            ForEach(Prayer.allCases) { prayer in
                Text(prayer.title)
                    .scaledFont(9.5, weight: .semibold)
                    .foregroundStyle(highlighted(prayer) ? Palette.accent.opacity(0.9)
                                                         : .white.opacity(0.42))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
        }
    }

    /// Ramazan ayında oruç için kritik olan iki sütun öne çıkıyor.
    private func highlighted(_ prayer: Prayer) -> Bool {
        viewModel.containsRamadan && (prayer == .imsak || prayer == .aksam)
    }
}

struct ImsakiyeTable: View {
    let viewModel: ImsakiyeViewModel

    @Environment(\.dynamicTypeSize) private var typeSize

    private let dateWidth = ImsakiyeLayout.dateWidth

    var body: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.rows()) { row in
                // Altı sütun 1.9x puntoda 393 pt genişliğe sığmıyor; ölçüldü,
                // bütün saatler "04:…" diye kırpılıyordu. Erişilebilirlik
                // boyutlarında satır blok düzenine geçiyor.
                if typeSize.isAccessibilitySize { stackedRow(row) } else { dayRow(row) }
                if row.day != viewModel.rows().last?.day {
                    Rectangle()
                        .fill(.white.opacity(0.05))
                        .frame(height: 1)
                }
            }
        }
    }

    /// Altı sütun tek tek okunursa hangi sayının hangi vakit olduğu kaybolur.
    private func rowLabel(_ row: ImsakiyeRow) -> String {
        let times = Prayer.allCases
            .map { "\($0.title) \(viewModel.formatted(row.times[$0]))" }
            .joined(separator: ", ")
        let prefix = row.isToday ? "Bugün, " : ""
        return "\(prefix)\(row.day) \(row.weekday), \(times)"
    }

    /// Büyük punto düzeni: gün başlığı üstte, vakitler ikili sütunlarda.
    private func stackedRow(_ row: ImsakiyeRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("\(row.day)")
                    .scaledFont(17, weight: row.isToday ? .bold : .semibold)
                    .monospacedDigit()
                Text(row.weekday)
                    .scaledFont(13)
                    .foregroundStyle(.white.opacity(0.45))
                if row.isToday {
                    Text("bugün")
                        .scaledFont(11, weight: .semibold)
                        .foregroundStyle(Palette.accent)
                }
            }

            ForEach([[Prayer.imsak, .gunes], [.ogle, .ikindi], [.aksam, .yatsi]], id: \.first) { pair in
                HStack(spacing: 0) {
                    ForEach(pair) { prayer in
                        HStack(spacing: 5) {
                            Text(prayer.title)
                                .scaledFont(13)
                                .foregroundStyle(.white.opacity(0.5))
                            Text(viewModel.formatted(row.times[prayer]))
                                .scaledFont(15, weight: .medium)
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .foregroundStyle(.white.opacity(row.isToday ? 1 : 0.8))
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background {
            if row.isToday {
                RoundedRectangle(cornerRadius: 10).fill(Palette.accent.opacity(0.12))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowLabel(row))
    }

    private func dayRow(_ row: ImsakiyeRow) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Text("\(row.day)")
                    .scaledFont(13, weight: row.isToday ? .bold : .medium)
                    .monospacedDigit()
                Text(row.weekday)
                    .scaledFont(10)
                    .foregroundStyle(.white.opacity(row.isToday ? 0.7 : 0.35))
            }
            .frame(width: dateWidth, alignment: .leading)

            ForEach(Prayer.allCases) { prayer in
                Text(viewModel.formatted(row.times[prayer]))
                    .scaledFont(12.5, weight: row.isToday ? .semibold : .regular)
                    .monospacedDigit()
                    .foregroundStyle(cellColor(prayer, row: row))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 9)
        .foregroundStyle(.white.opacity(row.isToday ? 1 : 0.75))
        .background {
            if row.isToday {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Palette.accent.opacity(0.12))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowLabel(row))
        .overlay(alignment: .leading) {
            if row.isToday {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Palette.accent)
                    .frame(width: 3, height: 20)
                    .offset(x: -10)
            }
        }
    }

    private func cellColor(_ prayer: Prayer, row: ImsakiyeRow) -> Color {
        if row.isRamadan && (prayer == .imsak || prayer == .aksam) {
            return Palette.accent
        }
        return .white.opacity(row.isToday ? 1 : 0.75)
    }
}
