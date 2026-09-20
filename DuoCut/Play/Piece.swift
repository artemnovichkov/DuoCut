import CoreGraphics
import Foundation

/// A cut-off piece on its way out of the frame.
///
/// Pieces are only for show: once a shape is cut, its halves get a push away from the blade
/// and tumble off screen while the score is settled.
struct Piece: Identifiable {
    let id = UUID()
    var polygon: Polygon
    var velocity: CGVector
    /// Radians per second around the piece's own centroid.
    var spin: Double
    var age = 0.0

    /// Fades out as it leaves.
    var opacity: Double { max(0, 1 - age / 1.6) }
    var isGone: Bool { age > 1.6 }

    /// Pushes the piece away from `line`, on the side it ended up on.
    init(polygon: Polygon, line: Line, speed: Double, spin: Double) {
        let side: Double = line.signedDistance(to: polygon.centroid) > 0 ? 1 : -1
        // The push is perpendicular to the cut: the blade opens the shape up.
        let normal = CGVector(dx: -line.direction.dy, dy: line.direction.dx)
        self.polygon = polygon
        self.velocity = CGVector(dx: normal.dx * speed * side, dy: normal.dy * speed * side)
        self.spin = spin * side
    }

    mutating func step(_ dt: Double, gravity: Double) {
        age += dt
        velocity.dy += gravity * dt
        polygon = polygon
            .translated(by: CGVector(dx: velocity.dx * dt, dy: velocity.dy * dt))
            .rotated(by: spin * dt, around: polygon.centroid)
    }
}
