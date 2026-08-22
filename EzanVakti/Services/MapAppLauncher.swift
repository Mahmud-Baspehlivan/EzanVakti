import MapKit
import UIKit

@MainActor
enum MapAppLauncher {
    /// Kurulu olmayan uygulamaya yönlendirmek sessizce hiçbir şey yapıyor;
    /// bu yüzden seçim listesinde yalnızca açılabilenler görünüyor.
    static var available: [MapApp] {
        MapApp.allCases.filter(isAvailable)
    }

    static func isAvailable(_ app: MapApp) -> Bool {
        guard let scheme = app.scheme else { return true }
        guard let url = URL(string: "\(scheme)://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    static func openDirections(to mosque: Mosque, using app: MapApp, mode: TravelMode) {
        guard app != .apple,
              let url = app.directionsURL(to: mosque.coordinate, mode: mode),
              UIApplication.shared.canOpenURL(url)
        else {
            openInAppleMaps(mosque, mode: mode)
            return
        }
        UIApplication.shared.open(url)
    }

    /// Apple Haritalar için `MKMapItem` yolu tercih ediliyor: hedef koordinat
    /// yerine cami adıyla görünüyor.
    private static func openInAppleMaps(_ mosque: Mosque, mode: TravelMode) {
        let coordinate = CLLocationCoordinate2D(latitude: mosque.coordinate.latitude,
                                                longitude: mosque.coordinate.longitude)
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = mosque.name
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: mode == .walking
                ? MKLaunchOptionsDirectionsModeWalking
                : MKLaunchOptionsDirectionsModeDriving
        ])
    }
}
