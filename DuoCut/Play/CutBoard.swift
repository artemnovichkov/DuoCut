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
    /// What the blade would do right now, recomputed as the player moves the shape.
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

    private let gravity = 1_600.0
    private var lastDate: Date?

    var isEmpty: Bool { shapes.isEmpty }

    func place(_ shapes: [Polygon], tokens: [Token] = []) {
        self.shapes = shapes
        self.tokens = tokens
        pieces = []
    }

    func clear() {
        shapes = []
        tokens = []
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

    /// Keeps the shapes reachable when a drag flings them past the edge.
    func keep(inside bounds: CGRect, margin: Double = 40) {
        guard !shapes.isEmpty else { return }
        var box = shapes[0].boundingBox
        for shape in shapes.dropFirst() { box = box.union(shape.boundingBox) }
        var dx = 0.0
        var dy = 0.0
        if box.maxX < bounds.minX + margin { dx = bounds.minX + margin - box.maxX }
        if box.minX > bounds.maxX - margin { dx = bounds.maxX - margin - box.minX }
        if box.maxY < bounds.minY + margin { dy = bounds.minY + margin - box.maxY }
        if box.minY > bounds.maxY - margin { dy = bounds.maxY - margin - box.minY }
        if dx != 0 || dy != 0 { translate(by: CGVector(dx: dx, dy: dy)) }
    }

    // MARK: - Cutting

    /// What the blade would do to the board as it stands, without touching anything.
    func preview(with line: Line) -> Outcome? {
        guard !shapes.isEmpty else { return nil }
        var positive = 0.0
        var negative = 0.0
        for shape in shapes {
            let areas = PolygonCut.split(shape, by: line).areas()
            positive += areas.positive
            negative += areas.negative
        }
        return outcome(positive: positive, negative: negative, line: line)
    }

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
        if keepPieces {
            shapes = positives + negatives
        } else {
            // A hard snap throws the pieces further, but never so far that they blink out.
            let launch = min(max(speed * 0.6, 140), 420)
            for polygon in positives + negatives {
                pieces.append(Piece(polygon: polygon, line: line, speed: launch, spin: .random(in: 0.6...2.4)))
            }
            shapes = []
            tokens = []
        }
        return outcome
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
