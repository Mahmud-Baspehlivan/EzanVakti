import SwiftUI

/// Uygulamayı kullanmaya başlamadan önceki birikmiş kaza borcunu girmek için.
/// Günlük takipten gelen "kılmadım" işaretleri buraya karışmıyor; ikisi ayrı
/// bileşen olarak toplanıp borç öyle hesaplanıyor.
struct QadaSetupView: View {
    let log: PrayerLogStore

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(PrayerLogStore.trackedPrayers) { prayer in
                        Stepper(value: opening(for: prayer), in: 0...100_000, step: 1) {
                            HStack {
                                Text(prayer.title)
                                Spacer()
                                Text("\(log.snapshot.qada.opening[prayer] ?? 0)")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Birikmiş borç")
                } footer: {
                    Text("Uygulamayı kullanmaya başlamadan önceki borcun. Günlük takipte \"Kılmadım\" işaretlediklerin buna otomatik ekleniyor, buraya elle yazman gerekmiyor.")
                }

                Section {
                    ForEach(PrayerLogStore.trackedPrayers) { prayer in
                        HStack {
                            Text(prayer.title)
                            Spacer()
                            Text("\(log.qadaBalance(for: prayer))")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            Button {
                                log.undoQadaPayment(for: prayer)
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                            }
                            .buttonStyle(.borderless)
                            .disabled((log.snapshot.qada.paid[prayer] ?? 0) == 0)
                        }
                    }
                } header: {
                    Text("Güncel borç")
                } footer: {
                    Text("Yanlışlıkla düştüğün bir kazayı geri almak için ok tuşunu kullan.")
                }
            }
            .navigationTitle("Kaza")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti") { dismiss() }
                }
            }
        }
    }

    private func opening(for prayer: Prayer) -> Binding<Int> {
        Binding(
            get: { log.snapshot.qada.opening[prayer] ?? 0 },
            set: { log.setOpeningQada($0, for: prayer) }
        )
    }
}
