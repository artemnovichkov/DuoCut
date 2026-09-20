import CoreGraphics
import Foundation

/// An infinite straight line: a point on it and a unit direction.
///
/// The cut line always lies on the hinge, so the game builds one of these from the
/// division reserved region and asks every shape which side of it each vertex is on.
nonisolated struct Line: Equatable {
    var point: CGPoint
    /// Unit vector along the line.
    var direction: CGVector

    init(point: CGPoint, direction: CGVector) {
        self.point = point
        let length = hypot(direction.dx, direction.dy)
        self.direction = length > 0 ? CGVector(dx: direction.dx / length, dy: direction.dy / length) : CGVector(dx: 1, dy: 0)
    }

    /// A vertical line through `x`, pointing down the screen.
    static func vertical(x: Double, y: Double = 0) -> Line {
        Line(point: CGPoint(x: x, y: y), direction: CGVector(dx: 0, dy: 1))
    }

    /// A horizontal line through `y`, pointing right.
    static func horizontal(y: Double, x: Double = 0) -> Line {
        Line(point: CGPoint(x: x, y: y), direction: CGVector(dx: 1, dy: 0))
    }

    /// Positive on one side, negative on the other, zero on the line.
    func signedDistance(to other: CGPoint) -> Double {
        let dx = other.x - point.x
        let dy = other.y - point.y
        // The z of the cross product of the direction and the offset.
        return direction.dx * dy - direction.dy * dx
    }

    /// How far along the line the projection of `other` sits, in points.
    func parameter(of other: CGPoint) -> Double {
        (other.x - point.x) * direction.dx + (other.y - point.y) * direction.dy
    }

    /// The point at `parameter` along the line.
    func point(at parameter: Double) -> CGPoint {
        CGPoint(x: point.x + direction.dx * parameter, y: point.y + direction.dy * parameter)
    }

    /// The same line rotated by `radians` around `center`, which stays on it.
    func rotated(by radians: Double, around center: CGPoint) -> Line {
        let cosine = cos(radians)
        let sine = sin(radians)
        let dx = point.x - center.x
        let dy = point.y - center.y
        return Line(
            point: CGPoint(x: center.x + dx * cosine - dy * sine, y: center.y + dx * sine + dy * cosine),
            direction: CGVector(
                dx: direction.dx * cosine - direction.dy * sine,
                dy: direction.dx * sine + direction.dy * cosine
            )
        )
    }
}
