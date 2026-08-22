import SwiftUI

/// Konum ve ağ servislerinden ayrı tutuluyor ki `Tools/render` ile Xcode
/// olmadan basılıp gözle denenebilsin.
struct NearbyMosquesContent: View {
    let state: MosqueSearchState
    let radius: MosqueSearchRadius
    let heading: DeviceHeading?
    var onSelect: (Mosque) -> Void = { _ in }
    var onRetry: () -> Void = {}

    var body: some View {
        switch state {
        case .idle:
            notice(symbol: "location", text: "Konumun bulununca yakındaki camiler listelenecek.")

        case .searching:
            VStack(spacing: 12) {
                ProgressView()
                    .tint(Palette.accent)
                Text("Camiler aranıyor…")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.vertical, 44)

        case .loaded(let mosques) where mosques.isEmpty:
            notice(symbol: "magnifyingglass",
                   text: "\(radius.title) içinde cami bulunamadı. Yarıçapı genişletmeyi dene.")

        case .loaded(let mosques):
            VStack(spacing: 10) {
                list(mosques)
                attribution
            }

        case .failed(let message):
            VStack(spacing: 14) {
                notice(symbol: "exclamationmark.triangle", text: message)
                Button(action: onRetry) {
                    Text("Tekrar dene")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.75))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background { Capsule().fill(Palette.accent) }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Liste

    private func list(_ mosques: [Mosque]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(mosques.enumerated()), id: \.element.id) { index, mosque in
                if index > 0 {
                    Rectangle()
                        .fill(.white.opacity(0.06))
                        .frame(height: 1)
                }
                row(mosque)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(.black.opacity(0.2))
        }
    }

    private func row(_ mosque: Mosque) -> some View {
        Button {
            onSelect(mosque)
        } label: {
            HStack(spacing: 12) {
                direction(for: mosque)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mosque.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)

                    if !mosque.address.isEmpty {
                        Text(mosque.address)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.42))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Text(mosque.distanceText)
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.accent)
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Telefon çevrildikçe ok camiyi göstermeye devam ediyor.
    @ViewBuilder
    private func direction(for mosque: Mosque) -> some View {
        if let heading, heading.isValid {
            Triangle()
                .fill(.white.opacity(0.7))
                .frame(width: 11, height: 13)
                .rotationEffect(.degrees(mosque.bearing - heading.degrees))
                .frame(width: 22)
                .animation(.interpolatingSpring(stiffness: 120, damping: 14),
                           value: heading.degrees)
        } else {
            Image(systemName: "mappin")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.3))
                .frame(width: 22)
        }
    }

    /// ODbL, OSM verisini kullanan uygulamalardan kaynak belirtmesini istiyor.
    private var attribution: some View {
        Text("Cami verisi © OpenStreetMap katkıcıları")
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.28))
            .frame(maxWidth: .infinity)
    }

    private func notice(symbol: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.3))
            Text(text)
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 36)
    }
}
