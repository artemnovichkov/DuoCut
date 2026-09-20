import CoreGraphics
import Foundation
import Observation

/// The shape under the blade, the pieces already cut off, and the physics that moves them.
///
/// Both modes play on a board: Puzzle puts one shape on it and scores the cut, Arcade throws
/// shapes across it. The board itself only knows how to hold a shape, cut it with a line, and
/// let the pieces fall.
@Observable
final class CutBoard {
    /// What the blade would do right now, recomputed as the player moves the shape.
    struct Preview: Equatable {
        var positive: Double
        var negative: Double

        var total: Double { positive + negative }
        /// 0.5 when the line splits the shape evenly.
        var share: Double { total > 0 ? positive / total : 0 }
        /// How far off an even split is, from 0 to 1.
        var error: Double { abs(share - 0.5) * 2 }
        var isCutting: Bool { positive > 0 && negative > 0 }
    }

    private(set) var shape: Polygon?
    private(set) var pieces: [Piece] = []
    /// Counts cuts, for haptics and animation triggers.
    private(set) var cuts = 0

    private let gravity = 1_600.0
    private var lastDate: Date?

    func place(_ polygon: Polygon) {
        shape = polygon
        pieces = []
    }

    func clear() {
        shape = nil
        pieces = []
    }

    // MARK: - Moving the shape under the blade

    func translate(by offset: CGVector) {
        shape = shape?.translated(by: offset)
    }

    func rotate(by radians: Double) {
        guard let shape else { return }
        self.shape = shape.rotated(by: radians, around: shape.centroid)
    }

    /// Keeps the shape reachable when a drag flings it past the edge.
    func keep(inside bounds: CGRect, margin: Double = 40) {
        guard let shape else { return }
        let box = shape.boundingBox
        var dx = 0.0
        var dy = 0.0
        if box.maxX < bounds.minX + margin { dx = bounds.minX + margin - box.maxX }
        if box.minX > bounds.maxX - margin { dx = bounds.maxX - margin - box.minX }
        if box.maxY < bounds.minY + margin { dy = bounds.minY + margin - box.maxY }
        if box.minY > bounds.maxY - margin { dy = bounds.maxY - margin - box.minY }
        if dx != 0 || dy != 0 { translate(by: CGVector(dx: dx, dy: dy)) }
    }

    // MARK: - Cutting

    func preview(with line: Line) -> Preview? {
        guard let shape else { return nil }
        let areas = PolygonCut.split(shape, by: line).areas()
        return Preview(positive: areas.positive, negative: areas.negative)
    }

    /// Cuts the shape along `line`. Returns what the cut turned out to be, or `nil` if the
    /// blade missed the shape entirely.
    @discardableResult
    func cut(with line: Line, speed: Double = 0) -> Preview? {
        guard let shape else { return nil }
        let result = PolygonCut.split(shape, by: line)
        guard result.isCut else { return nil }
        let areas = result.areas()
        // A hard snap throws the pieces further, but never so far that they blink out.
        let launch = min(max(speed * 0.6, 140), 420)
        for polygon in result.positive + result.negative {
            pieces.append(Piece(polygon: polygon, line: line, speed: launch, spin: .random(in: 0.6...2.4)))
        }
        self.shape = nil
        cuts += 1
        return Preview(positive: areas.positive, negative: areas.negative)
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
