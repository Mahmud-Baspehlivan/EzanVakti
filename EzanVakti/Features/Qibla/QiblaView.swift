import SwiftUI

struct QiblaView: View {
    let location: LocationProvider

    @State private var viewModel = QiblaViewModel()

    private var isAligned: Bool {
        guard let heading = location.heading, heading.isValid else { return false }
        return viewModel.isAligned(heading: heading.degrees)
    }

    var body: some View {
        QiblaContent(
            viewModel: viewModel,
            heading: location.heading,
            isHeadingAvailable: location.isHeadingAvailable,
            now: Date()
        )
        .onAppear { location.startHeading() }
        .onDisappear { location.stopHeading() }
        .onChange(of: location.state) { _, _ in
            viewModel.apply(location.state)
        }
        .sensoryFeedback(.success, trigger: isAligned)
    }
}

/// Pusula göstergeleri için basit üçgen.
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
