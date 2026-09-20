import CoreGraphics
import Foundation

/// A cut-off piece on its way out of the frame.
///
/// Pieces are only for show: once a shape is cut, its halves get a push away from the blade
/// and tumble off screen while the score is settled. Tokens ride along on the piece they
/// ended up on, so the player can see which side each one went to.
struct Piece: Identifiable {
    let id = UUID()
    var polygon: Polygon
    /// Tokens that were sitting on this piece when it came off.
    var tokens: [Token]
    var velocity: CGVector
    /// Radians per second around the piece's own centroid.
    var spin: Double
    var age = 0.0

    /// Fades out as it leaves.
    var opacity: Double { max(0, 1 - age / 1.6) }
    var isGone: Bool { age > 1.6 }

    /// Pushes the piece away from `line`, on the side it ended up on.
    init(polygon: Polygon, tokens: [Token] = [], line: Line, speed: Double, spin: Double) {
        let side: Double = line.signedDistance(to: polygon.centroid) > 0 ? 1 : -1
        // The push is perpendicular to the cut: the blade opens the shape up.
        let normal = CGVector(dx: -line.direction.dy, dy: line.direction.dx)
        self.polygon = polygon
        self.tokens = tokens
        self.velocity = CGVector(dx: normal.dx * speed * side, dy: normal.dy * speed * side)
        self.spin = spin * side
    }

    mutating func step(_ dt: Double, gravity: Double) {
        age += dt
        velocity.dy += gravity * dt
        let offset = CGVector(dx: velocity.dx * dt, dy: velocity.dy * dt)
        let moved = polygon.translated(by: offset)
        let pivot = moved.centroid
        let turn = spin * dt
        polygon = moved.rotated(by: turn, around: pivot)
        guard !tokens.isEmpty else { return }
        let cosine = cos(turn)
        let sine = sin(turn)
        tokens = tokens.map { token in
            var moved = token
            let dx = token.position.x + offset.dx - pivot.x
            let dy = token.position.y + offset.dy - pivot.y
            moved.position = CGPoint(
                x: pivot.x + dx * cosine - dy * sine,
                y: pivot.y + dx * sine + dy * cosine
            )
            return moved
        }
    }
}
