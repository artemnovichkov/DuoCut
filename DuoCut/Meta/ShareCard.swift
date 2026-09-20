import SwiftUI

/// The picture that goes out to a chat: the shape, the cut, and the number.
struct ShareCard: View {
    let title: String
    let shapes: [Polygon]
    let line: Line?
    let detail: String
    let stars: Int
    let streak: Int?

    var body: some View {
        VStack(spacing: 22) {
            Text(title)
                .font(.system(size: 26, weight: .black, design: .rounded))
            drawing
                .frame(width: 320, height: 320)
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: index < stars ? "star.fill" : "star")
                            .font(.system(size: 22))
                            .foregroundStyle(index < stars ? Palette.shapeAlternate : Palette.ink.opacity(0.18))
                    }
                }
                Text(detail)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if let streak {
                    Text("\(streak) day streak")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.ink.opacity(0.45))
                }
            }
            Text("DuoCut · fold to cut")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.35))
        }
        .foregroundStyle(Palette.ink)
        .padding(40)
        .frame(width: 440, height: 620)
        .background(Palette.paper)
    }

    /// The shape as it was cut, drawn to fit the card.
    private var drawing: some View {
        Canvas { context, size in
            guard let box = boundingBox else { return }
            let scale = min(size.width / max(box.width, 1), size.height / max(box.height, 1)) * 0.9
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -box.midX, y: -box.midY)
            for shape in shapes {
                context.fill(shape.path, with: .color(Palette.shape))
            }
            if let line {
                let span = max(box.width, box.height) * 2
                var path = Path()
                path.move(to: line.point(at: -span))
                path.addLine(to: line.point(at: span))
                context.stroke(path, with: .color(Palette.blade), lineWidth: 3 / scale)
            }
        }
    }

    private var boundingBox: CGRect? {
        guard var box = shapes.first?.boundingBox else { return nil }
        for shape in shapes.dropFirst() { box = box.union(shape.boundingBox) }
        return box
    }

    /// The card as an image, ready for `ShareLink`.
    @MainActor
    func rendered() -> Image? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3
        guard let image = renderer.uiImage else { return nil }
        return Image(uiImage: image)
    }
}
