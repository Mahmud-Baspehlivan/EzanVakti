import Foundation

extension Coordinate {
    /// Kuş uçuşu uzaklık (metre). Küre yaklaşımı: şehir içi mesafelerde
    /// elipsoit düzeltmesi metre altı fark yapıyor.
    func distance(to other: Coordinate) -> Double {
        let earthRadius = 6_371_000.0
        let dLat = other.latitude - latitude
        let dLon = other.longitude - longitude
        let a = pow(Deg.sin(dLat / 2), 2)
            + Deg.cos(latitude) * Deg.cos(other.latitude) * pow(Deg.sin(dLon / 2), 2)
        return 2 * earthRadius * asin(min(1, a.squareRoot()))
    }

    /// Hedefe yön: kuzeyden saat yönünde derece.
    func bearing(to other: Coordinate) -> Double {
        let dLon = other.longitude - longitude
        let y = Deg.sin(dLon) * Deg.cos(other.latitude)
        let x = Deg.cos(latitude) * Deg.sin(other.latitude)
            - Deg.sin(latitude) * Deg.cos(other.latitude) * Deg.cos(dLon)
        return Deg.wrap(Deg.atan2(y, x), max: 360)
    }
}
