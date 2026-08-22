import MapKit
import SwiftUI

struct LocationSuggestion: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let coordinate: Coordinate

    static func == (lhs: LocationSuggestion, rhs: LocationSuggestion) -> Bool { lhs.id == rhs.id }
}

@MainActor
@Observable
final class LocationSearchModel {
    var query = ""
    private(set) var results: [LocationSuggestion] = []
    private(set) var isSearching = false
    private(set) var message: String?

    private var task: Task<Void, Never>?

    /// Arama ağ gerektiriyor; ama seçim yapıldıktan sonra koordinat kaydedildiği
    /// için uygulamanın geri kalanı çevrimdışı çalışmaya devam ediyor.
    func search() {
        task?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= 2 else {
            results = []
            message = nil
            return
        }

        task = Task {
            isSearching = true
            defer { isSearching = false }

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = trimmed
            request.resultTypes = .address

            do {
                let response = try await MKLocalSearch(request: request).start()
                guard !Task.isCancelled else { return }

                var seen = Set<String>()
                results = response.mapItems.compactMap { item -> LocationSuggestion? in
                    let place = item.placemark
                    let name = item.name ?? place.locality ?? place.name
                    guard let name else { return nil }

                    let coordinate = Coordinate(latitude: place.coordinate.latitude,
                                                longitude: place.coordinate.longitude)
                    let key = "\(name)|\(Int(coordinate.latitude * 1000))|\(Int(coordinate.longitude * 1000))"
                    guard seen.insert(key).inserted else { return nil }

                    let detail = [place.subAdministrativeArea, place.administrativeArea, place.country]
                        .compactMap { $0 }
                        .filter { $0 != name }
                    return LocationSuggestion(
                        id: key, name: name,
                        subtitle: Array(Set(detail)).sorted().joined(separator: ", "),
                        coordinate: coordinate
                    )
                }
                message = results.isEmpty ? "Sonuç bulunamadı." : nil
            } catch {
                guard !Task.isCancelled else { return }
                results = []
                // Arama tek internet gerektiren yer; sessizce boş liste göstermek
                // kullanıcıya yanlış bilgi verirdi.
                message = "Arama yapılamadı. İnternet bağlantını kontrol et."
            }
        }
    }
}

struct LocationPickerView: View {
    let location: LocationProvider

    @Environment(\.dismiss) private var dismiss
    @State private var model = LocationSearchModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        location.setMode(.automatic)
                        dismiss()
                    } label: {
                        HStack {
                            Label("Konumumu kullan", systemImage: "location.fill")
                            Spacer()
                            if !location.mode.isManual {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                } footer: {
                    if let manual = location.mode.manualName {
                        Text("Şu an elle seçilmiş konum kullanılıyor: \(manual)")
                    } else {
                        Text("Vakitler bulunduğun yere göre hesaplanıyor.")
                    }
                }

                Section {
                    if model.isSearching {
                        HStack { ProgressView(); Text("Aranıyor…").foregroundStyle(.secondary) }
                    }

                    ForEach(model.results) { suggestion in
                        Button {
                            location.setMode(.manual(
                                latitude: suggestion.coordinate.latitude,
                                longitude: suggestion.coordinate.longitude,
                                name: suggestion.name
                            ))
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.name)
                                if !suggestion.subtitle.isEmpty {
                                    Text(suggestion.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if let message = model.message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Şehir veya ilçe ara")
                } footer: {
                    Text("Arama için internet gerekiyor. Seçtikten sonra vakitler çevrimdışı hesaplanır.")
                }
            }
            .searchable(text: $model.query, prompt: "Örn. Eyüpsultan, Konya, Berlin")
            .onChange(of: model.query) { _, _ in model.search() }
            .navigationTitle("Konum")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}
