import SwiftUI

struct ImsakiyeView: View {
    let location: LocationProvider

    @State private var viewModel = ImsakiyeViewModel()

    var body: some View {
        ZStack {
            Palette.background(for: nil)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ImsakiyeHeader(
                    viewModel: viewModel,
                    onStep: { viewModel.step($0) },
                    onToday: { viewModel.goToCurrentMonth() }
                )

                // Sütun adları kaydırma alanının dışında; satırlar akarken
                // hangi sütunun hangi vakit olduğu görünür kalıyor.
                ImsakiyeColumnHeader(viewModel: viewModel)

                ScrollViewReader { proxy in
                    ScrollView {
                        ImsakiyeTable(viewModel: viewModel)
                            .padding(.bottom, 12)
                    }
                    .onAppear {
                        guard viewModel.isShowingCurrentMonth,
                              let today = viewModel.rows().first(where: \.isToday) else { return }
                        proxy.scrollTo(today.id, anchor: .center)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .onChange(of: location.state) { _, _ in
            viewModel.apply(location.state)
        }
    }
}
