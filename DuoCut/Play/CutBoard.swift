import CoreGraphics
import Foundation
import Observation

/// The shapes under the blade, the pieces already cut off, and the physics that moves them.
///
/// Both modes play on a board: Puzzle puts a shape on it and scores the cut, Arcade throws
/// shapes across it. The board itself only knows how to hold shapes, cut them with a line, and
/// let the leftovers fall.
@Observable
final class CutBoard {
    /// What a cut turned out to be. The player only ever sees this after the blade lands —
    /// showing it while aiming would turn the game into dialing a number to 50.0.
    struct Outcome: Equatable {
        var positiveArea: Double
        var negativeArea: Double
        /// Tokens that ended up on each side.
        var positiveTokens: [Token] = []
        var negativeTokens: [Token] = []

        var total: Double { positiveArea + negativeArea }
        /// 0.5 when the line splits the shape evenly.
        var share: Double { total > 0 ? positiveArea / total : 0 }
        var isCutting: Bool { positiveArea > 0 && negativeArea > 0 }

        /// How far the split is from `target`, from 0 to 1.
        func error(against target: Double) -> Double {
            abs(share - target) / max(target, 1 - target)
        }
    }

    private(set) var shapes: [Polygon] = []
    private(set) var tokens: [Token] = []
    private(set) var pieces: [Piece] = []
    /// Counts cuts, for haptics and animation triggers.
    private(set) var cuts = 0
    /// The last cut, kept for the share card.
    private(set) var lastCutLine: Line?
    private(set) var lastCutShapes: [Polygon] = []

    private let gravity = 1_600.0
    private var lastDate: Date?

    var isEmpty: Bool { shapes.isEmpty }
    /// The area of every piece still on the board, which is how a multi-cut level is scored.
    var shapeAreas: [Double] { shapes.map(\.area) }

    func place(_ shapes: [Polygon], tokens: [Token] = []) {
        self.shapes = shapes
        self.tokens = tokens
        pieces = []
    }

    // MARK: - Moving the shapes under the blade

    /// The point everything turns around: the area-weighted center of what's on the board.
    var center: CGPoint {
        let total = shapes.reduce(0) { $0 + $1.area }
        guard total > 0 else { return .zero }
        let x = shapes.reduce(0) { $0 + $1.centroid.x * $1.area } / total
        let y = shapes.reduce(0) { $0 + $1.centroid.y * $1.area } / total
        return CGPoint(x: x, y: y)
    }

    /// The box around everything on the board.
    var boundingBox: CGRect {
        guard var box = shapes.first?.boundingBox else { return .zero }
        for shape in shapes.dropFirst() { box = box.union(shape.boundingBox) }
        return box
    }

    func contains(_ point: CGPoint) -> Bool {
        shapes.contains { $0.contains(point) }
    }

    func translate(by offset: CGVector) {
        shapes = shapes.map { $0.translated(by: offset) }
        tokens = tokens.map {
            var token = $0
            token.position = CGPoint(x: $0.position.x + offset.dx, y: $0.position.y + offset.dy)
            return token
        }
    }

    func rotate(by radians: Double) {
        let pivot = center
        shapes = shapes.map { $0.rotated(by: radians, around: pivot) }
        let cosine = cos(radians)
        let sine = sin(radians)
        tokens = tokens.map {
            var token = $0
            let dx = $0.position.x - pivot.x
            let dy = $0.position.y - pivot.y
            token.position = CGPoint(x: pivot.x + dx * cosine - dy * sine, y: pivot.y + dx * sine + dy * cosine)
            return token
        }
    }

    /// Keeps the middle of the shape on screen, so a fling can never put it out of reach.
    func keep(inside bounds: CGRect, margin: Double = 40) {
        guard !shapes.isEmpty else { return }
        let box = boundingBox
        let inset = CGRect(
            x: bounds.minX + min(margin, bounds.width / 3),
            y: bounds.minY + min(margin, bounds.height / 3),
            width: max(0, bounds.width - 2 * min(margin, bounds.width / 3)),
            height: max(0, bounds.height - 2 * min(margin, bounds.height / 3))
        )
        var dx = 0.0
        var dy = 0.0
        if box.midX < inset.minX { dx = inset.minX - box.midX }
        if box.midX > inset.maxX { dx = inset.maxX - box.midX }
        if box.midY < inset.minY { dy = inset.minY - box.midY }
        if box.midY > inset.maxY { dy = inset.maxY - box.midY }
        if dx != 0 || dy != 0 { translate(by: CGVector(dx: dx, dy: dy)) }
    }

    // MARK: - Cutting

    /// Cuts everything on the board along `line`. Returns what the cut turned out to be, or
    /// `nil` when the blade missed. With `keepPieces`, the halves stay on the board for the
    /// next cut instead of flying off.
    @discardableResult
    func cut(with line: Line, speed: Double = 0, keepPieces: Bool = false) -> Outcome? {
        guard !shapes.isEmpty else { return nil }
        var positives: [Polygon] = []
        var negatives: [Polygon] = []
        for shape in shapes {
            let result = PolygonCut.split(shape, by: line)
            positives += result.positive
            negatives += result.negative
        }
        guard !positives.isEmpty, !negatives.isEmpty else { return nil }

        let outcome = outcome(
            positive: positives.reduce(0) { $0 + $1.area },
            negative: negatives.reduce(0) { $0 + $1.area },
            line: line
        )
        cuts += 1
        lastCutLine = line
        lastCutShapes = positives + negatives
        if keepPieces {
            shapes = positives + negatives
        } else {
            scatter(positives + negatives, from: line, speed: speed)
        }
        return outcome
    }

    /// Throws whatever is still on the board away from `line`. The last cut of a multi-cut
    /// level ends this way, so those levels get the same payoff as a single cut.
    func scatter(from line: Line, speed: Double = 0) {
        guard !shapes.isEmpty else { return }
        scatter(shapes, from: line, speed: speed)
    }

    private func scatter(_ polygons: [Polygon], from line: Line, speed: Double) {
        // A hard snap throws the pieces further, but never so far that they blink out.
        let launch = min(max(speed * 0.6, 140), 420)
        for polygon in polygons {
            let carried = tokens.filter { polygon.contains($0.position) }
            pieces.append(Piece(
                polygon: polygon,
                tokens: carried,
                line: line,
                speed: launch,
                spin: .random(in: 0.6...2.4)
            ))
        }
        shapes = []
        tokens = []
    }

    private func outcome(positive: Double, negative: Double, line: Line) -> Outcome {
        Outcome(
            positiveArea: positive,
            negativeArea: negative,
            positiveTokens: tokens.filter { line.signedDistance(to: $0.position) > 0 },
            negativeTokens: tokens.filter { line.signedDistance(to: $0.position) <= 0 }
        )
    }

    // MARK: - Physics

    func step(to date: Date) {
        let dt = lastDate.map { min(date.timeIntervalSince($0), 1.0 / 30) } ?? 0
        lastDate = date
        guard dt > 0, !pieces.isEmpty else { return }
        for index in pieces.indices {
            pieces[index].step(dt, gravity: gravity)
        }
        pieces.removeAll { $0.isGone }
    }
}
