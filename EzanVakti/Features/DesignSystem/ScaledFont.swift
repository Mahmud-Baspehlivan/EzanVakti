import SwiftUI

/// Sabit punto veren `.font(.system(size:))` Dynamic Type'ı hiç dinlemiyor:
/// kullanıcı yazıyı büyütse de uygulamada hiçbir şey değişmiyordu.
///
/// Anlamsal stiller (`.body`, `.caption`) kendiliğinden ölçekleniyor ama bu
/// tasarımdaki punto kademeleri onlara oturmuyor. Bu yüzden çarpanı ortamdan
/// okuyup puntoya kendimiz uyguluyoruz. Yan fayda: `ImageRenderer` ile
/// istenen boyutta render edip düzeni gözle denetleyebiliyoruz —
/// `UIFontMetrics` kullanılsaydı bu mümkün olmazdı.
extension DynamicTypeSize {
    var fontScale: CGFloat {
        switch self {
        case .xSmall:         return 0.82
        case .small:          return 0.88
        case .medium:         return 0.94
        case .large:          return 1.00
        case .xLarge:         return 1.12
        case .xxLarge:        return 1.24
        case .xxxLarge:       return 1.35
        case .accessibility1: return 1.60
        case .accessibility2: return 1.90
        case .accessibility3: return 2.35
        case .accessibility4: return 2.75
        case .accessibility5: return 3.10
        @unknown default:     return 1.00
        }
    }
}

private struct ScaledFont: ViewModifier {
    @Environment(\.dynamicTypeSize) private var typeSize

    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        content.font(.system(size: size * typeSize.fontScale, weight: weight, design: design))
    }
}

extension View {
    /// Dynamic Type ile ölçeklenen sistem fontu.
    func scaledFont(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> some View {
        modifier(ScaledFont(size: size, weight: weight, design: design))
    }
}
