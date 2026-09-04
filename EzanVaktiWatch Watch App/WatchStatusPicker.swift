import SwiftUI

/// Bir vakti bilekten işaretleme ekranı.
///
/// Telefondaki gibi "dokundukça sıradaki duruma geç" yapılmadı: orada satır
/// listenin içinde duruyor ve yanlış duruma geçmek bir dokunuş uzakta. Saatte
/// hedef küçük, dokunuş çoğu zaman yürürken oluyor ve yanlış işareti düzeltmek
/// üç dokunuş daha demek. Açık seçim, döngüden pahalı değil — ekran zaten
/// dokunuşla açılıyor.
struct WatchStatusPicker: View {
    let prayer: Prayer
    let time: String
    let current: PrayerStatus
    let onSelect: (PrayerStatus) -> Void

    var body: some View {
        ScrollView {
            WatchStatusPickerContent(prayer: prayer, time: time,
                                     current: current, onSelect: onSelect)
        }
    }
}

/// Kaydırma kabuğundan ayrı: `ImageRenderer` ScrollView içeriğini basmıyor,
/// bu haliyle seçim ekranı Xcode olmadan gözle denetlenebiliyor.
struct WatchStatusPickerContent: View {
    let prayer: Prayer
    let time: String
    let current: PrayerStatus
    var onSelect: (PrayerStatus) -> Void = { _ in }

    /// Sıra kullanım sıklığına göre: en sık "kıldım", en seyrek "işareti kaldır".
    private static let choices: [PrayerStatus] = [.performed, .congregation, .missed, .unmarked]

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Text(prayer.title)
                    .font(.system(size: 15, weight: .semibold))
                Text(time)
                    .font(.system(size: 15))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 2)

            ForEach(Self.choices) { choice in
                Button { onSelect(choice) } label: { row(choice) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 2)
    }

    private func row(_ choice: PrayerStatus) -> some View {
        let isCurrent = choice == current
        return HStack(spacing: 8) {
            Image(systemName: choice == .unmarked ? "arrow.uturn.backward" : choice.symbolName)
                .font(.system(size: 15))
                .frame(width: 20)
                .foregroundStyle(choice == .unmarked ? Color.secondary : choice.tint)
            Text(choice == .unmarked ? "İşareti kaldır" : choice.title)
                .font(.system(size: 15))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            if isCurrent {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.accent)
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(choice == .unmarked ? Color.white.opacity(0.08) : choice.tint.opacity(0.18))
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(choice == .unmarked ? "İşareti kaldır" : choice.title)
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }
}
