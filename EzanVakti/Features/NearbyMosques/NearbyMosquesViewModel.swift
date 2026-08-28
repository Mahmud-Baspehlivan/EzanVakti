import Foundation
import Observation

/// "Aranıyor", "cami yok" ve "internet yok" ekranda farklı şeyler söylüyor;
/// üçünü boş listeye indirmek yanlış bilgi vermek olurdu.
enum MosqueSearchState {
    case idle
    case searching
    case loaded([Mosque])
    case failed(String)
}

@MainActor
@Observable
final class NearbyMosquesViewModel {
    private(set) var state: MosqueSearchState = .idle
    private(set) var locationName: String?
    private(set) var radius: MosqueSearchRadius = .district
    private(set) var coordinate: Coordinate?

    /// GPS sabit dururken bile birkaç on metre zıplıyor; bu eşiğin altı aynı
    /// konum sayılıyor.
    private static let significantMove: Double = 50

    private var task: Task<Void, Never>?

    func apply(_ locationState: LocationState) {
        switch locationState {
        case .resolved(let coordinate, let name):
            let movedEnough = self.coordinate
                .map { $0.distance(to: coordinate) > Self.significantMove } ?? true
            self.coordinate = coordinate
            self.locationName = name
            if movedEnough || isIdle { reload() }

        case .denied:
            state = .failed("Yakındaki camileri bulmak için konum izni gerekiyor.")
        case .failed(let message):
            state = .failed(message)
        case .idle, .requesting:
            break
        }
    }

    func select(_ newRadius: MosqueSearchRadius) {
        guard newRadius != radius else { return }
        radius = newRadius
        // Eldeki liste artık yanlış yarıçapa ait.
        state = .searching
        reload()
    }

    func reload() {
        guard let coordinate else { return }
        task?.cancel()
        task = Task {
            // Geçerli liste varken göstergeye çevirmiyoruz; aşağı çekince
            // liste kaybolup geri gelmiş gibi oluyor.
            if !hasResults { state = .searching }
            do {
                let mosques = try await MosqueFinder.search(
                    near: coordinate,
                    radius: radius.rawValue
                )
                guard !Task.isCancelled else { return }
                state = .loaded(mosques)
            } catch is CancellationError {
                // Arama iptal edildi (yarıçap değişti ya da yeni bir arama
                // başladı). `Task.isCancelled` çoğu durumda bunu zaten yakalıyor
                // ama iptal artık `MosqueFinder`'dan da geliyor; kullanıcıya
                // "Bu işlem iptal edildi" diye bir hata göstermek yanlış olurdu.
                return
            } catch {
                guard !Task.isCancelled else { return }
                // Yoğunluk, sunucu hatası ve bağlantı yokluğu farklı şeyler;
                // hepsini "internet yok" diye göstermek kullanıcıyı yanlış
                // yere bakmaya yollar.
                state = .failed(error.localizedDescription)
            }
        }
    }

    /// `refreshable` aramanın bitmesini beklemek zorunda, yoksa çekme
    /// göstergesi liste gelmeden kayboluyor.
    func refresh() async {
        reload()
        await task?.value
    }

    private var isIdle: Bool {
        if case .idle = state { return true }
        return false
    }

    private var hasResults: Bool {
        if case .loaded(let mosques) = state { return !mosques.isEmpty }
        return false
    }
}
