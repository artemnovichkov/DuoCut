import SwiftUI

/// Draws the board and takes the input that moves the shape under the blade.
///
/// One finger drags the shape, two fingers rotate it, and a snap of the hinge cuts. On a phone
/// without a hinge, a swipe across the cut line does the cutting instead.
struct CutBoardView: View {
    let board: CutBoard
    /// Called with the result of every cut the player lands.
    var onCut: (CutBoard.Preview) -> Void = { _ in }

    @State private var detector = CutDetector()
    @State private var hinge: DeviceHinge?
    @State private var lastDragTranslation = CGSize.zero
    @State private var lastRotation = SwiftUI.Angle.zero
    @State private var dragStart: CGPoint?

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
                    if let shape = board.shape {
                        context.fill(shape.path, with: .color(Palette.shape))
                        context.stroke(shape.path, with: .color(Palette.ink.opacity(0.15)), lineWidth: 1)
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
            // 👇 The API: a snap of the hinge is the cut.
            .onHingeChange { _, newContext in
                hinge = newContext.hinge
                guard let degrees = newContext.hinge?.angle.degrees else { return }
                if let snap = detector.update(degrees: degrees, at: Date.timeIntervalSinceReferenceDate) {
                    cut(with: fold.line, speed: snap.speed)
                }
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: board.cuts)
    }

    private func cut(with line: Line, speed: Double) {
        guard let result = board.cut(with: line, speed: speed) else { return }
        onCut(result)
    }

    /// Dragging the shape moves it; dragging anywhere else across the blade cuts, so the game
    /// still works on a phone that doesn't fold.
    private func dragGesture(fold: FoldLine, bounds: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStart == nil {
                    dragStart = value.startLocation
                    lastDragTranslation = .zero
                }
                guard board.shape?.contains(value.startLocation) == true else { return }
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
                }
                guard board.shape?.contains(value.startLocation) != true else { return }
                let crossed = fold.line.signedDistance(to: value.startLocation)
                    * fold.line.signedDistance(to: value.location) < 0
                if crossed {
                    let length = hypot(value.translation.width, value.translation.height)
                    cut(with: fold.line, speed: length)
                }
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
