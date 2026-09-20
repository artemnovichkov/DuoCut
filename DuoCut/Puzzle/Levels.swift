import CoreGraphics
import Foundation

/// A themed run of levels. Packs get harder from left to right, and so do the levels inside them.
struct Pack: Identifiable, Equatable {
    var id: String
    var title: String
    var subtitle: String
    var levels: [Level]
    /// Stars needed in the packs before this one to open it.
    var starsToUnlock = 0
}

enum Levels {
    static let packs: [Pack] = [basics]

    /// Straight shapes first, then the ones where the eye starts to lie.
    static let basics = Pack(
        id: "basics",
        title: "Basics",
        subtitle: "Learn the blade",
        levels: [
            Level(
                id: "basics-square",
                title: "Square",
                goal: .equalHalves,
                shapes: [.rectangle(CGRect(x: -0.8, y: -0.8, width: 1.6, height: 1.6))],
                startOffset: CGVector(dx: 40, dy: 0)
            ),
            Level(
                id: "basics-hexagon",
                title: "Hexagon",
                goal: .equalHalves,
                shapes: [.regular(sides: 6, radius: 0.9)],
                startRotation: 0.35,
                startOffset: CGVector(dx: -50, dy: 20)
            ),
            Level(
                id: "basics-triangle",
                title: "Triangle",
                goal: .equalHalves,
                shapes: [.regular(sides: 3, radius: 1)],
                startRotation: 0.7,
                startOffset: CGVector(dx: 30, dy: -10)
            ),
            Level(
                id: "basics-slab",
                title: "Slab",
                goal: .equalHalves,
                shapes: [.rectangle(CGRect(x: -1.1, y: -0.45, width: 2.2, height: 0.9))],
                startRotation: -0.25,
                startOffset: CGVector(dx: -30, dy: 30)
            ),
            Level(
                id: "basics-ell",
                title: "Elbow",
                goal: .equalHalves,
                shapes: [Polygon([
                    CGPoint(x: -0.9, y: -0.9), CGPoint(x: 0.3, y: -0.9), CGPoint(x: 0.3, y: -0.2),
                    CGPoint(x: 0.9, y: -0.2), CGPoint(x: 0.9, y: 0.9), CGPoint(x: -0.9, y: 0.9)
                ])],
                startRotation: 0.2,
                startOffset: CGVector(dx: 20, dy: 0)
            ),
            Level(
                id: "basics-star",
                title: "Star",
                goal: .equalHalves,
                shapes: [.star(points: 5, outerRadius: 1, innerRadius: 0.42)],
                startRotation: 0.5,
                startOffset: CGVector(dx: -20, dy: -20)
            ),
            Level(
                id: "basics-cee",
                title: "Horseshoe",
                goal: .equalHalves,
                shapes: [Polygon([
                    CGPoint(x: -0.9, y: -0.9), CGPoint(x: 0.9, y: -0.9), CGPoint(x: 0.9, y: -0.45),
                    CGPoint(x: -0.35, y: -0.45), CGPoint(x: -0.35, y: 0.45), CGPoint(x: 0.9, y: 0.45),
                    CGPoint(x: 0.9, y: 0.9), CGPoint(x: -0.9, y: 0.9)
                ])],
                startRotation: -0.4,
                startOffset: CGVector(dx: 40, dy: 10)
            ),
            Level(
                id: "basics-third",
                title: "A Third",
                goal: .ratio(1.0 / 3),
                shapes: [.regular(sides: 12, radius: 0.95)],
                startOffset: CGVector(dx: -40, dy: 0)
            )
        ]
    )
}
