import SwiftUI

/// Bir vaktin işaret satırı.
///
/// "Bugün" kartı ile geçmiş gün sayfası aynı satırı kullanıyor; tek fark hangi
/// güne yazdığı. Renkler anlamsal (`.primary` / `.secondary`) çünkü satır hem
/// koyu kartın hem sistem `Form`'unun içinde duruyor.
struct PrayerStatusRow: View {
    let prayer: Prayer
    let status: PrayerStatus
    /// Vakti girmemiş namaz işaretlenemiyor; kural `PrayerMarking`'te.
    let isMarkable: Bool
    let onAdvance: () -> Void

    var body: some View {
        Button(action: onAdvance) {
            HStack(spacing: 12) {
                Image(systemName: prayer.symbolName)
                    .scaledFont(15)
                    .frame(width: 22)
                    .foregroundStyle(.secondary)
                Text(prayer.title)
                Spacer()
                trailing
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isMarkable)
        // Kapalı satır soluyor ama kayboluyor değil: gün içinde nereye
        // gelindiği de bir bilgi.
        .opacity(isMarkable ? 1 : 0.45)
        // Dokundukça durum değiştiği için etiket-değer-ipucu üçlüsü gerekiyor:
        // ne olduğu, hangi durumda olduğu, ne olacağı.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(prayer.title)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(isMarkable ? "Sıradaki duruma geçmek için dokun: \(status.next.title)" : "")
    }

    @ViewBuilder
    private var trailing: some View {
        if isMarkable {
            Text(status.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(status == .unmarked ? AnyShapeStyle(.secondary) : AnyShapeStyle(status.tint))
            Image(systemName: status.symbolName)
                .scaledFont(19)
                .foregroundStyle(status.tint)
        } else {
            // Sebebi yazılı: satırın neden kapalı olduğu başka hiçbir yerden
            // anlaşılmıyor ve kullanıcı bunu bir arıza sanabilir.
            Text("vakti girmedi")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Image(systemName: "clock")
                .scaledFont(19)
                .foregroundStyle(.secondary)
        }
    }

    private var accessibilityValue: String {
        guard isMarkable else { return "vakti girmedi" }
        return status == .unmarked ? "işaretlenmedi" : status.title
    }
}
