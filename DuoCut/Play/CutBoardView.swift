import SwiftUI

/// Draws the board and takes the input that moves the shape under the blade.
///
/// One finger drags the shape, two fingers rotate it, and a snap of the hinge cuts. On a phone
/// without a hinge, a swipe across the cut line does the cutting instead.
struct CutBoardView: View {
    let board: CutBoard
    /// Multi-cut levels keep the halves on the board instead of throwing them away.
    var keepPieces = false
    /// Called with the result of every cut the player lands.
    var onCut: (CutBoard.Outcome) -> Void = { _ in }
    /// Called when the blade came down but touched nothing.
    var onMiss: () -> Void = {}
    /// Called on every layout with the live fold line, so the screen above can lay out around it.
    var onFoldChange: (FoldLine) -> Void = { _ in }
    /// Called for every snap of the hinge, whether or not the blade hit anything.
    var onSnap: () -> Void = {}
    /// Called with whether this device actually has a hinge, for the on-screen hint.
    var onHinge: (Bool) -> Void = { _ in }

    @State private var detector = CutDetector()
    @State private var dragStart: CGPoint?
    @State private var isMovingShape = false
    @State private var lastDragTranslation = CGSize.zero
    @State private var lastRotation = SwiftUI.Angle.zero

    /// How far a swipe has to travel before it counts as a cut rather than a stray touch.
    private let swipeToCut = 60.0

    var body: some View {
        GeometryReader { proxy in
            let fold = FoldLine.from(proxy)

            TimelineView(.animation) { timeline in
                Canvas { context, _ in
                    for piece in board.pieces {
                        context.opacity = piece.opacity
                        context.fill(piece.polygon.path, with: .color(Palette.shape))
                        for token in piece.tokens { draw(token, in: &context) }
                    }
                    context.opacity = 1
                    for (index, shape) in board.shapes.enumerated() {
                        // Several pieces on the board are drawn a hair apart and a shade
                        // different, so the player can see the cut that already landed.
                        let drawn = board.shapes.count > 1 ? inset(shape) : shape
                        let color = board.shapes.count > 1 ? Palette.piece(index) : Palette.shape
                        context.fill(drawn.path, with: .color(color))
                        context.stroke(drawn.path, with: .color(Palette.ink.opacity(0.15)), lineWidth: 1)
                    }
                    for token in board.tokens {
                        draw(token, in: &context)
                    }
                }
                .onChange(of: timeline.date, initial: true) { _, date in
                    board.step(to: date)
                }
            }
            .background { FoldBand(fold: fold) }
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
                onHinge(newContext.hinge != nil)
                guard let degrees = newContext.hinge?.angle.degrees else { return }
                if let snap = detector.update(degrees: degrees, at: Date.timeIntervalSinceReferenceDate) {
                    onSnap()
                    cut(with: fold.line, speed: snap.speed)
                }
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: board.cuts)
    }

    /// Pulls a piece a couple of points in from its own edge, which shows up as a seam
    /// between two pieces that used to be one shape.
    private func inset(_ shape: Polygon) -> Polygon {
        let box = shape.boundingBox
        let reach = max(box.width, box.height)
        guard reach > 12 else { return shape }
        return shape.scaled(by: 1 - 4 / reach, around: shape.centroid)
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
        guard let outcome = board.cut(with: line, speed: speed, keepPieces: keepPieces) else {
            // The blade came down on empty paper. Say so instead of doing nothing.
            if !board.isEmpty { onMiss() }
            return
        }
        onCut(outcome)
    }

    /// Dragging a shape moves it; a long enough drag anywhere else across the blade cuts, so
    /// the game still works on a phone that doesn't fold.
    private func dragGesture(fold: FoldLine, bounds: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // A gesture that starts somewhere new is a new drag, even if the last one
                // was cancelled without an end.
                if dragStart != value.startLocation {
                    dragStart = value.startLocation
                    lastDragTranslation = .zero
                    isMovingShape = board.contains(value.startLocation)
                }
                guard isMovingShape else { return }
                let delta = CGVector(
                    dx: value.translation.width - lastDragTranslation.width,
                    dy: value.translation.height - lastDragTranslation.height
                )
                lastDragTranslation = value.translation
                board.translate(by: delta)
                board.keep(inside: bounds)
            }
            .onEnded { value in
                defer {
                    dragStart = nil
                    lastDragTranslation = .zero
                    isMovingShape = false
                }
                guard !isMovingShape, !board.contains(value.startLocation) else { return }
                let length = hypot(value.translation.width, value.translation.height)
                guard length >= swipeToCut else { return }
                let crossed = fold.line.signedDistance(to: value.startLocation)
                    * fold.line.signedDistance(to: value.location) < 0
                guard crossed else { return }
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
