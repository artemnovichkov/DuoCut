import CoreGraphics
import Foundation

/// Something tossed across the blade.
struct Flyer: Identifiable {
    enum Kind {
        case fruit, bomb
    }

    let id = UUID()
    var polygon: Polygon
    var velocity: CGVector
    var spin: Double
    var kind: Kind

    mutating func step(_ dt: Double, gravity: Double) {
        velocity.dy += gravity * dt
        polygon = polygon
            .translated(by: CGVector(dx: velocity.dx * dt, dy: velocity.dy * dt))
            .rotated(by: spin * dt, around: polygon.centroid)
    }

    /// True once it has fallen back out of the bottom of the screen.
    func hasFallen(below height: Double) -> Bool {
        velocity.dy > 0 && polygon.boundingBox.minY > height
    }
}
