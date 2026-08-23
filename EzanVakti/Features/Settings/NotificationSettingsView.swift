import AVFoundation
import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @Bindable var store: NotificationPreferencesStore
    let scheduler: PrayerNotificationScheduler

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVAudioPlayer?

    private let reminderOptions = [0, 5, 10, 15, 30]

    private var selectedSound: NotificationSound {
        NotificationSoundCatalog.sound(id: store.preferences.soundID)
    }

    var body: some View {
        NavigationStack {
            Form {
                if scheduler.authorization == .denied {
                    Section {
                        Label(
                            "Bildirim izni kapalı. Ayarlar › Ezan Vakti › Bildirimler'den açman gerekiyor.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(.orange)
                    }
                }

                Section("Vakitler") {
                    ForEach(Prayer.allCases) { prayer in
                        Toggle(prayer.title, isOn: binding(for: prayer))
                    }
                }

                Section("Hatırlatma") {
                    Picker("Ne zaman", selection: $store.preferences.minutesBefore) {
                        ForEach(reminderOptions, id: \.self) { minutes in
                            Text(minutes == 0 ? "Vaktinde" : "\(minutes) dk önce").tag(minutes)
                        }
                    }
                }

                Section {
                    Toggle("Kilit ekranında geri sayım", isOn: $store.preferences.liveActivityEnabled)
                } footer: {
                    Text("Sıradaki vakte kalan süre kilit ekranında ve Dinamik Ada'da görünür. Uygulama her açıldığında sıradaki vakte kurulur; vakit girdikten sonra bir sonrakinin görünmesi için uygulamayı yeniden açman gerekir (arka planda kurulması sunucu gerektiriyor).")
                }

                soundSection

                Section {
                    LabeledContent("Planlanan bildirim", value: "\(scheduler.scheduledCount)")
                    if let error = scheduler.lastError {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                } footer: {
                    Text("iOS bir uygulamaya en fazla 64 bekleyen bildirim veriyor ve vakitler her gün değiştiği için her biri tek tek planlanıyor. Uygulamayı iki haftada bir açmazsan bildirimler kesilir.")
                }
            }
            .navigationTitle("Bildirimler")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var soundSection: some View {
        let available = NotificationSoundCatalog.available

        Section {
            Picker("Ses", selection: $store.preferences.soundID) {
                ForEach(available) { sound in
                    Text(sound.title).tag(sound.id)
                }
            }

            if selectedSound.fileName != nil {
                Button {
                    preview(selectedSound)
                } label: {
                    Label("Sesi dinle", systemImage: "play.circle")
                }
            }

            // Seçili ses kayıtlıydı ama dosya artık pakette yoksa iOS sessizce
            // varsayılana düşer; bunu gizlemek yerine söylüyoruz.
            if !selectedSound.isBundled {
                Label(
                    "\(selectedSound.fileName ?? "Ses dosyası") uygulama paketinde yok, sistem sesi kullanılacak.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
        } header: {
            Text("Ses")
        } footer: {
            if available.count == 1 {
                Text("Henüz özel ses eklenmemiş. Ses dosyasını EzanVakti/ klasörünün köküne koyup projeyi yeniden derlemen gerekiyor. Biçim: .caf, .aiff veya .wav (MP3 çalışmaz), en fazla 30 saniye.")
            } else {
                Text("Özel bildirim sesleri en fazla 30 saniye olabilir; daha uzun dosyalarda iOS sistem sesine düşer.")
            }
        }
    }

    private func preview(_ sound: NotificationSound) {
        guard let fileName = sound.fileName,
              let url = Bundle.main.url(forResource: fileName, withExtension: nil)
        else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }

    private func binding(for prayer: Prayer) -> Binding<Bool> {
        Binding(
            get: { store.preferences.enabled.contains(prayer) },
            set: { isOn in
                if isOn { store.preferences.enabled.insert(prayer) }
                else { store.preferences.enabled.remove(prayer) }
            }
        )
    }
}
