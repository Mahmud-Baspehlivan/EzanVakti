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
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                        .buttonStyle(.plain)
                }
            }

            HStack(spacing: 0) {
                stepButton(-1, "chevron.left")
                VStack(spacing: 2) {
                    Text(viewModel.monthTitle)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(viewModel.hijriSpan)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                stepButton(1, "chevron.right")
            }

            Text(viewModel.locationName)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func stepButton(_ delta: Int, _ symbol: String) -> some View {
        Button { onStep(delta) } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    var body: some View {
        HStack(spacing: 0) {
            // Yükseklik bilerek sabitlendi: yalnız genişlik verilen Color.clear
            // dikeyde açgözlü davranıp başlığı ekranın yarısı kadar şişiriyordu.
            Color.clear.frame(width: ImsakiyeLayout.dateWidth, height: 1)
            ForEach(Prayer.allCases) { prayer in
                Text(prayer.title)
                    .font(.system(size: 9.5, weight: .semibold))
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

    private let dateWidth = ImsakiyeLayout.dateWidth

    var body: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.rows()) { row in
                dayRow(row)
                if row.day != viewModel.rows().last?.day {
                    Rectangle()
                        .fill(.white.opacity(0.05))
                        .frame(height: 1)
                }
            }
        }
    }

    private func dayRow(_ row: ImsakiyeRow) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Text("\(row.day)")
                    .font(.system(size: 13, weight: row.isToday ? .bold : .medium))
                    .monospacedDigit()
                Text(row.weekday)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(row.isToday ? 0.7 : 0.35))
            }
            .frame(width: dateWidth, alignment: .leading)

            ForEach(Prayer.allCases) { prayer in
                Text(viewModel.formatted(row.times[prayer]))
                    .font(.system(size: 12.5, weight: row.isToday ? .semibold : .regular))
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
