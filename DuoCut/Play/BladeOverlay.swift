import SwiftUI

/// The reserved band of the fold, drawn *under* the shapes.
///
/// It has to sit below them: painted on top it tints whatever is being cut and reads as a
/// smudge across the shape.
struct FoldBand: View {
    let fold: FoldLine

    var body: some View {
        GeometryReader { proxy in
            let (start, end) = fold.endpoints(in: proxy.size)
            if fold.thickness > 0 {
                Path { path in
                    path.move(to: start)
                    path.addLine(to: end)
                }
                .stroke(Palette.ink.opacity(0.07), lineWidth: fold.thickness)
            }
        }
        .allowsHitTesting(false)
    }
}

/// The blade, drawn right on the fold.
///
/// It's what the player aims by, so it stays clearly visible at rest — with a tick at each
/// end to mark the line — and brightens as the hinge starts to close, so the cut can be felt
/// coming before it lands.
struct BladeOverlay: View {
    let fold: FoldLine
    /// 0 to 1, from `CutDetector.tension`.
    var tension: Double

    var body: some View {
        GeometryReader { proxy in
            let (start, end) = fold.endpoints(in: proxy.size)
            ZStack {
                blade(from: start, to: end)
                    .stroke(
                        Palette.blade.opacity(0.5 + tension * 0.5),
                        style: .init(lineWidth: 2.5 + tension * 3, lineCap: .round)
                    )
                    .shadow(color: Palette.blade.opacity(tension * 0.8), radius: tension * 12)
                ticks(in: proxy.size)
                    .stroke(Palette.blade.opacity(0.8), style: .init(lineWidth: 3, lineCap: .round))
            }
        }
        .allowsHitTesting(false)
    }

    private func blade(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }

    /// Short marks where the blade meets the edges of the board, so the line is unmistakable.
    private func ticks(in size: CGSize) -> Path {
        let length = 11.0
        var path = Path()
        switch fold.axis {
        case .vertical:
            let x = fold.line.point.x
            for y in [8.0, size.height - 8] {
                path.move(to: CGPoint(x: x - length, y: y))
                path.addLine(to: CGPoint(x: x + length, y: y))
            }
        case .horizontal:
            let y = fold.line.point.y
            for x in [8.0, size.width - 8] {
                path.move(to: CGPoint(x: x, y: y - length))
                path.addLine(to: CGPoint(x: x, y: y + length))
            }
        }
        return path
    }
}
