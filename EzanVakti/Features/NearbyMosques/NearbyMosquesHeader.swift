import SwiftUI

enum NearbyMosquesMode {
    case list
    case map

    var toggled: NearbyMosquesMode { self == .list ? .map : .list }

    var symbolName: String { self == .list ? "map" : "list.bullet" }
}

struct NearbyMosquesHeader: View {
    let locationName: String?
    let radius: MosqueSearchRadius
    let mode: NearbyMosquesMode
    /// Harita boş listeyi sessizce göstermesin diye düğme yalnızca sonuç
    /// varken çıkıyor.
    let canShowMap: Bool
    var onSelectRadius: (MosqueSearchRadius) -> Void = { _ in }
    var onToggleMode: () -> Void = {}

    var body: some View {
        VStack(spacing: 5) {
            SectionLabel(text: "Yakındaki Camiler")
                .frame(maxWidth: .infinity)
                .overlay(alignment: .trailing) {
                    if canShowMap { modeButton }
                }

            Text(locationName ?? "Konum bekleniyor")
                .scaledFont(25, weight: .medium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            CapsuleSegments(options: MosqueSearchRadius.allCases,
                            selection: radius,
                            title: \.title,
                            onSelect: onSelectRadius)
                .padding(.top, 13)
        }
        .padding(.top, 12)
    }

    private var modeButton: some View {
        Button(action: onToggleMode) {
            Image(systemName: mode.symbolName)
                .scaledFont(14)
                .foregroundStyle(Palette.accent)
                .frame(width: 34, height: 28)
                .background { Capsule().fill(.white.opacity(0.07)) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode == .list ? "Haritada göster" : "Listede göster")
    }
}

/// Uygulamanın koyu diline uyan segment seçici; `Picker(.segmented)` açık
/// gri zeminiyle burada yabancı duruyor.
struct CapsuleSegments<Option: Identifiable & Equatable>: View {
    let options: [Option]
    let selection: Option
    let title: KeyPath<Option, String>
    var onSelect: (Option) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options) { option in
                Button {
                    onSelect(option)
                } label: {
                    Text(option[keyPath: title])
                        .scaledFont(13, weight: .semibold)
                        .monospacedDigit()
                        .foregroundStyle(option == selection
                                         ? .black.opacity(0.75)
                                         : .white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            Capsule().fill(option == selection
                                           ? Palette.accent
                                           : Color.white.opacity(0.06))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Arama yarıçapı \(option[keyPath: title])")
                .accessibilityAddTraits(option == selection ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

struct MapAppFooter: View {
    let apps: [MapApp]
    let selected: MapApp
    var onSelect: (MapApp) -> Void = { _ in }

    var body: some View {
        // Tek uygulama varsa seçim diye bir şey yok.
        if apps.count > 1 {
            Menu {
                ForEach(apps) { app in
                    Button {
                        onSelect(app)
                    } label: {
                        if app == selected {
                            Label(app.title, systemImage: "checkmark")
                        } else {
                            Text(app.title)
                        }
                    }
                }
            } label: {
                MapAppFooterLabel(app: selected)
            }
        }
    }
}

/// `Menu`'yü `ImageRenderer` basamıyor; etiket ayrı tutulunca görünüm
/// Xcode'suz kontrol edilebiliyor.
struct MapAppFooterLabel: View {
    let app: MapApp

    var body: some View {
        HStack(spacing: 5) {
            Text("Yol tarifi")
                .foregroundStyle(.white.opacity(0.4))
            Text(app.title)
                .foregroundStyle(Palette.accent)
            Image(systemName: "chevron.up.chevron.down")
                .scaledFont(9)
                .foregroundStyle(Palette.accent.opacity(0.7))
        }
        .scaledFont(12)
    }
}
