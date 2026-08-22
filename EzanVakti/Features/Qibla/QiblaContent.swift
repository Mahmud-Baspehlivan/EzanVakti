import SwiftUI

/// Kıble ekranının görsel gövdesi. Konum/pusula servislerinden ayrı tutuluyor ki
/// `Tools/render` ile Xcode olmadan basılıp gözle denenebilsin.
struct QiblaContent: View {
    let viewModel: QiblaViewModel
    let heading: DeviceHeading?
    let isHeadingAvailable: Bool
    let now: Date

    var isAligned: Bool {
        guard let heading, heading.isValid else { return false }
        return viewModel.isAligned(heading: heading.degrees)
    }

    var body: some View {
        ZStack {
            Palette.background(for: nil)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                readout
                compass
                Spacer(minLength: 8)
                qiblaTimeCard
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
        }
    }


    private var readout: some View {
        VStack(spacing: 5) {
            SectionLabel(text: "Kıble")

            // Yön kısaltma yerine tam adıyla: "GGD" çoğu kişiye bir şey ifade etmiyor.
            Text(viewModel.compassName(for: viewModel.direction))
                .scaledFont(29, weight: .medium)
                .foregroundStyle(.white)

            Text("\(Int(viewModel.direction.rounded()))°")
                .scaledFont(15)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.top, 16)
    }

    private var compass: some View {
        VStack(spacing: 12) {
            ZStack {
                // Kadran tümüyle görsel; bilgiyi ortadaki TurnIndicator taşıyor.
                // Erişilebilirliği burada toplamak, yön güncellemesi hızında
                // (saniyede onlarca kez) erişilebilirlik ağacını yeniden
                // kurdurup takılmaya yol açıyordu.
                QiblaDial(
                    qiblaDirection: viewModel.direction,
                    heading: heading?.degrees ?? 0,
                    isAligned: isAligned,
                    // 30° aralıkta sayılardan biri sürekli Kâbe rozetinin altında
                    // kalıyor; 45° hem okunur hem çakışmıyor.
                    degreeLabels: .every45
                )
                .animation(.interpolatingSpring(stiffness: 120, damping: 14),
                           value: heading?.degrees ?? 0)
                .accessibilityHidden(true)

                // Talimat kadranla dönmesin diye kadranın üstünde, ayrı katmanda.
                compassCenter

                VStack {
                    Triangle()
                        .fill(isAligned ? Color(red: 0.35, green: 0.82, blue: 0.48)
                                        : .white.opacity(0.8))
                        .frame(width: 14, height: 12)
                    Spacer()
                }
            }
            .frame(width: 296, height: 296)

            if let heading, heading.needsCalibration {
                Text("Pusula sapmalı — telefonu havada sekiz çizerek kalibre et, metal ve mıknatıstan uzaklaş.")
                    .scaledFont(12)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.accent.opacity(0.8))
                    .padding(.horizontal, 12)
            }
        }
        .padding(.top, 18)
    }

    /// Pusulanın durumu sözle: yön bilgisi yalnızca çizimde olduğu için
    /// VoiceOver kullanıcısı aksi halde hiçbir şey duyamıyor.
    private var compassAccessibilityValue: String {
        guard let heading, heading.isValid else {
            return isHeadingAvailable ? "Pusula okunuyor" : "Bu cihazda pusula yok"
        }
        if isAligned { return "Kıble yönündesin" }
        let deviation = viewModel.deviation(from: heading.degrees)
        let yon = deviation > 0 ? "sağa" : "sola"
        // 15°'lik kademeye yuvarlanıyor: her derecede değişen bir değer,
        // erişilebilirlik ağacını saniyede onlarca kez yeniden kurduruyor.
        let kademe = max(15, Int((abs(deviation) / 15).rounded()) * 15)
        return "yaklaşık \(kademe) derece \(yon) dön"
    }

    @ViewBuilder
    private var compassCenter: some View {
        if let heading, heading.isValid {
            TurnIndicator(
                deviation: viewModel.deviation(from: heading.degrees),
                isAligned: isAligned
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Kıble pusulası")
            .accessibilityValue(compassAccessibilityValue)
        } else {
            VStack(spacing: 6) {
                Image(systemName: isHeadingAvailable ? "location.north.line" : "location.slash")
                    .scaledFont(26)
                Text(isHeadingAvailable ? "Pusula okunuyor…" : "Bu cihazda pusula yok")
                    .scaledFont(14)
            }
            .foregroundStyle(.white.opacity(isHeadingAvailable ? 0.45 : 0.7))
        }
    }

    private var qiblaTimeCard: some View {
        let times = viewModel.qiblaTimes(on: now)

        return VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 0) {
                stat(label: "Kıble Saati",
                     value: times.isEmpty ? "yok"
                                          : times.map(viewModel.formattedMinute).joined(separator: " · "))
                Rectangle()
                    .fill(.white.opacity(0.10))
                    .frame(width: 1, height: 38)
                stat(label: "Kâbe'ye", value: viewModel.distanceText)
            }

            Text(times.isEmpty
                 ? "Bugün güneş kıble yönüne gelmiyor. Bu enlemde her tarihte olmuyor."
                 : "Bu saatte güneş tam kıble yönünde olur; dik bir cismin gölgesi kıblenin tam tersini gösterir. Pusulasız doğrulamanın en güvenilir yolu.")
                .scaledFont(12)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(.black.opacity(0.22))
        }
        .padding(.bottom, 20)
    }

    private func stat(label: String, value: String) -> some View {
        VStack(spacing: 5) {
            SectionLabel(text: label, size: 10, tracking: 1.2)
            Text(value)
                .scaledFont(22, weight: .semibold)
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }
}
