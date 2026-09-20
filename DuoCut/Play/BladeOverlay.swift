import SwiftUI

/// The blade, drawn right on the fold.
///
/// It brightens as the hinge starts to close, so the player can feel the cut coming before
/// it lands. Without a hinge it's a thin guide line instead.
struct BladeOverlay: View {
    let fold: FoldLine
    /// 0 to 1, from `CutDetector.tension`.
    var tension: Double

    var body: some View {
        GeometryReader { proxy in
            let (start, end) = fold.endpoints(in: proxy.size)
            ZStack {
                if fold.thickness > 0 {
                    line(from: start, to: end)
                        .stroke(Palette.ink.opacity(0.06), lineWidth: fold.thickness)
                }
                line(from: start, to: end)
                    .stroke(Palette.blade.opacity(0.25 + tension * 0.75), style: .init(lineWidth: 1.5 + tension * 2.5))
                    .shadow(color: Palette.blade.opacity(tension * 0.8), radius: tension * 12)
            }
        }
        .allowsHitTesting(false)
    }

    private func line(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}
