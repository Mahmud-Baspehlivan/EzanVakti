import MapKit
import SwiftUI

struct NearbyMosquesMap: View {
    let mosques: [Mosque]
    let center: Coordinate
    /// Elle konum seçilmişken kullanıcının gerçek yeri haritada kilometrelerce
    /// uzakta çıkıyor ve konum düğmesi haritayı oraya atıyor; o durumda gizliyoruz.
    var showsUserLocation = true
    var onSelect: (Mosque) -> Void = { _ in }

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedID: String?

    var body: some View {
        Map(position: $position, selection: $selectedID) {
            if showsUserLocation {
                UserAnnotation()
            }

            ForEach(mosques) { mosque in
                Marker(mosque.name, systemImage: "building.2",
                       coordinate: coordinate(of: mosque))
                    .tint(Palette.accent)
                    .tag(mosque.id)
            }
        }
        // Apple'ın kendi ilgi noktaları camileri gölgeliyor.
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
            if showsUserLocation {
                MapUserLocationButton()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(alignment: .bottom) { selectionCard }
        .onAppear { position = .region(region) }
        .onChange(of: regionKey) { _, _ in position = .region(region) }
    }

    /// Kadrajı elle kuruyoruz: `.automatic` elle seçilmiş konumda kullanıcının
    /// gerçek yerini de sığdırmaya çalışıp haritayı ülke ölçeğine çekiyor.
    private var region: MKCoordinateRegion {
        let farthest = mosques.map(\.distance).max() ?? 400
        let span = max(farthest * 2.6, 800)
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: center.latitude,
                                           longitude: center.longitude),
            latitudinalMeters: span,
            longitudinalMeters: span
        )
    }

    private var regionKey: String {
        "\(center.latitude),\(center.longitude),\(mosques.count),\(mosques.last?.id ?? "")"
    }

    private func coordinate(of mosque: Mosque) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: mosque.coordinate.latitude,
                               longitude: mosque.coordinate.longitude)
    }

    @ViewBuilder
    private var selectionCard: some View {
        if let mosque = mosques.first(where: { $0.id == selectedID }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(mosque.name)
                        .scaledFont(15, weight: .medium)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(mosque.address.isEmpty ? mosque.distanceText
                                                : "\(mosque.distanceText) · \(mosque.address)")
                        .scaledFont(12)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    onSelect(mosque)
                } label: {
                    Text("Yol tarifi")
                        .scaledFont(13, weight: .semibold)
                        .foregroundStyle(.black.opacity(0.75))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background { Capsule().fill(Palette.accent) }
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            // Harita zemini açık tonlara çıkabiliyor; kart burada daha opak.
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.black.opacity(0.62))
            }
            .padding(10)
        }
    }
}
