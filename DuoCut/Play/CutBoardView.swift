import SwiftUI

/// Draws the board and takes the input that moves the shape under the blade.
///
/// One finger drags the shape, two fingers rotate it, and a snap of the hinge cuts. On a phone
/// without a hinge, a swipe across the cut line does the cutting instead.
struct CutBoardView: View {
    let board: CutBoard
    /// Multi-cut levels keep the halves on the board instead of throwing them away.
    var keepPieces = false
    /// Called with the fold line and the result of every cut the player lands.
    var onCut: (CutBoard.Outcome) -> Void = { _ in }
    /// Called on every layout with the live fold line, so the screen above can show a preview.
    var onFoldChange: (FoldLine) -> Void = { _ in }
    /// Called for every snap of the hinge, whether or not the blade hit anything.
    var onSnap: () -> Void = {}

    @State private var detector = CutDetector()
    @State private var hasHinge = false
    @State private var lastDragTranslation = CGSize.zero
    @State private var lastRotation = SwiftUI.Angle.zero

    var body: some View {
        GeometryReader { proxy in
            let fold = FoldLine.from(proxy)

            TimelineView(.animation) { timeline in
                Canvas { context, _ in
                    for piece in board.pieces {
                        context.opacity = piece.opacity
                        context.fill(piece.polygon.path, with: .color(Palette.shape))
                    }
                    context.opacity = 1
                    for shape in board.shapes {
                        context.fill(shape.path, with: .color(Palette.shape))
                        context.stroke(shape.path, with: .color(Palette.ink.opacity(0.15)), lineWidth: 1)
                    }
                    for token in board.tokens {
                        draw(token, in: &context)
                    }
                }
                .onChange(of: timeline.date, initial: true) { _, date in
                    board.step(to: date)
                }
            }
            .overlay {
                BladeOverlay(fold: fold, tension: detector.tension)
            }
            .contentShape(.rect)
            .gesture(dragGesture(fold: fold, bounds: CGRect(origin: .zero, size: proxy.size)))
            .simultaneousGesture(rotateGesture)
            .onChange(of: fold, initial: true) { _, newFold in
                onFoldChange(newFold)
            }
            // 👇 The API: a snap of the hinge is the cut.
            .onHingeChange { _, newContext in
                hasHinge = newContext.hinge != nil
                guard let degrees = newContext.hinge?.angle.degrees else { return }
                if let snap = detector.update(degrees: degrees, at: Date.timeIntervalSinceReferenceDate) {
                    onSnap()
                    cut(with: fold.line, speed: snap.speed)
                }
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: board.cuts)
    }

    private func draw(_ token: Token, in context: inout GraphicsContext) {
        let radius = 11.0
        switch token.color {
        case .star:
            let star = Polygon.star(points: 5, outerRadius: radius * 1.3, innerRadius: radius * 0.55, center: token.position)
            context.fill(star.path, with: .color(Palette.shapeAlternate))
        case .red, .blue:
            let dot = Path(ellipseIn: CGRect(
                x: token.position.x - radius,
                y: token.position.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            context.fill(dot, with: .color(token.color == .red ? Palette.blade : Palette.ink))
        }
    }

    private func cut(with line: Line, speed: Double) {
        guard let outcome = board.cut(with: line, speed: speed, keepPieces: keepPieces) else { return }
        onCut(outcome)
    }

    /// Dragging a shape moves it; dragging anywhere else across the blade cuts, so the game
    /// still works on a phone that doesn't fold.
    private func dragGesture(fold: FoldLine, bounds: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard board.contains(value.startLocation) else { return }
                let delta = CGVector(
                    dx: value.translation.width - lastDragTranslation.width,
                    dy: value.translation.height - lastDragTranslation.height
                )
                lastDragTranslation = value.translation
                board.translate(by: delta)
                board.keep(inside: bounds)
            }
            .onEnded { value in
                defer { lastDragTranslation = .zero }
                guard !board.contains(value.startLocation) else { return }
                let crossed = fold.line.signedDistance(to: value.startLocation)
                    * fold.line.signedDistance(to: value.location) < 0
                guard crossed else { return }
                let length = hypot(value.translation.width, value.translation.height)
                cut(with: fold.line, speed: length)
            }
    }

    private var rotateGesture: some Gesture {
        RotateGesture()
            .onChanged { value in
                board.rotate(by: value.rotation.radians - lastRotation.radians)
                lastRotation = value.rotation
            }
            .onEnded { _ in
                lastRotation = .zero
            }
    }
}
