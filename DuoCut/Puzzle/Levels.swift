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
    static let packs: [Pack] = [basics, fruit, constellations, mosaic]

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
                startOffset: CGVector(dx: 0.80, dy: 0.00)
            ),
            Level(
                id: "basics-hexagon",
                title: "Hexagon",
                goal: .equalHalves,
                shapes: [.regular(sides: 6, radius: 0.9)],
                startRotation: 0.35,
                startOffset: CGVector(dx: -1.00, dy: 0.40)
            ),
            Level(
                id: "basics-triangle",
                title: "Triangle",
                goal: .equalHalves,
                shapes: [.regular(sides: 3, radius: 1)],
                startRotation: 0.7,
                startOffset: CGVector(dx: 0.60, dy: -0.20)
            ),
            Level(
                id: "basics-slab",
                title: "Slab",
                goal: .equalHalves,
                shapes: [.rectangle(CGRect(x: -1.1, y: -0.45, width: 2.2, height: 0.9))],
                startRotation: -0.25,
                startOffset: CGVector(dx: -0.60, dy: 0.60)
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
                startOffset: CGVector(dx: 0.40, dy: 0.00)
            ),
            Level(
                id: "basics-star",
                title: "Star",
                goal: .equalHalves,
                shapes: [.star(points: 5, outerRadius: 1, innerRadius: 0.42)],
                startRotation: 0.5,
                startOffset: CGVector(dx: -0.40, dy: -0.40)
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
                startOffset: CGVector(dx: 0.80, dy: 0.20)
            ),
            Level(
                id: "basics-third",
                title: "A Third",
                goal: .ratio(1.0 / 3),
                shapes: [.regular(sides: 12, radius: 0.95)],
                startOffset: CGVector(dx: -0.80, dy: 0.00)
            )
        ]
    )

    /// Round, lumpy shapes where the eye is a bad judge of area.
    static let fruit = Pack(
        id: "fruit",
        title: "Fruit",
        subtitle: "Curves lie",
        levels: [
            Level(
                id: "fruit-plum",
                title: "Plum",
                goal: .equalHalves,
                shapes: [.regular(sides: 24, radius: 0.85)],
                startOffset: CGVector(dx: 1.20, dy: -0.20)
            ),
            Level(
                id: "fruit-pear",
                title: "Pear",
                goal: .equalHalves,
                shapes: [pear],
                startRotation: 0.6,
                startOffset: CGVector(dx: -0.80, dy: 0.40)
            ),
            Level(
                id: "fruit-banana",
                title: "Banana",
                goal: .equalHalves,
                shapes: [crescent],
                startRotation: -0.5,
                startOffset: CGVector(dx: 0.60, dy: 0.00)
            ),
            Level(
                id: "fruit-slice",
                title: "Melon Slice",
                goal: .ratio(0.25),
                shapes: [.regular(sides: 20, radius: 0.9)],
                startOffset: CGVector(dx: -1.20, dy: 0.20)
            ),
            Level(
                id: "fruit-bunch",
                title: "Bunch",
                goal: .equalHalves,
                shapes: [
                    .regular(sides: 14, radius: 0.42, center: CGPoint(x: -0.45, y: -0.3)),
                    .regular(sides: 14, radius: 0.5, center: CGPoint(x: 0.42, y: -0.1)),
                    .regular(sides: 14, radius: 0.38, center: CGPoint(x: -0.1, y: 0.55))
                ],
                startRotation: 0.3
            ),
            Level(
                id: "fruit-core",
                title: "Core",
                goal: .ratio(1.0 / 3),
                shapes: [apple],
                startRotation: 0.25,
                startOffset: CGVector(dx: 0.80, dy: -0.40)
            )
        ],
        starsToUnlock: 8
    )

    /// Levels where the tokens, not the area, decide the cut.
    static let constellations = Pack(
        id: "constellations",
        title: "Constellations",
        subtitle: "Count, don't measure",
        levels: [
            Level(
                id: "stars-four",
                title: "Four",
                goal: .tokensPerSide(2),
                shapes: [.regular(sides: 20, radius: 0.9)],
                tokens: [
                    Token(position: CGPoint(x: -0.45, y: -0.4), color: .star),
                    Token(position: CGPoint(x: -0.4, y: 0.45), color: .star),
                    Token(position: CGPoint(x: 0.42, y: -0.35), color: .star),
                    Token(position: CGPoint(x: 0.5, y: 0.3), color: .star)
                ],
                startRotation: 0.4
            ),
            Level(
                id: "stars-six",
                title: "Six",
                goal: .tokensPerSide(3),
                shapes: [.rectangle(CGRect(x: -1, y: -0.6, width: 2, height: 1.2))],
                tokens: [
                    Token(position: CGPoint(x: -0.7, y: -0.3), color: .star),
                    Token(position: CGPoint(x: -0.65, y: 0.3), color: .star),
                    Token(position: CGPoint(x: -0.2, y: 0), color: .star),
                    Token(position: CGPoint(x: 0.25, y: -0.3), color: .star),
                    Token(position: CGPoint(x: 0.6, y: 0.25), color: .star),
                    Token(position: CGPoint(x: 0.8, y: -0.1), color: .star)
                ],
                startRotation: -0.3,
                startOffset: CGVector(dx: 0.60, dy: 0.00)
            ),
            Level(
                id: "stars-sort",
                title: "Sorting",
                goal: .separateColors,
                shapes: [.regular(sides: 6, radius: 0.95)],
                tokens: [
                    Token(position: CGPoint(x: -0.5, y: -0.25), color: .red),
                    Token(position: CGPoint(x: -0.45, y: 0.3), color: .red),
                    Token(position: CGPoint(x: 0.45, y: -0.3), color: .blue),
                    Token(position: CGPoint(x: 0.5, y: 0.25), color: .blue)
                ],
                startRotation: 0.9
            ),
            Level(
                id: "stars-interleaved",
                title: "Woven",
                goal: .separateColors,
                shapes: [.rectangle(CGRect(x: -1, y: -0.55, width: 2, height: 1.1))],
                tokens: [
                    Token(position: CGPoint(x: -0.75, y: -0.3), color: .red),
                    Token(position: CGPoint(x: -0.25, y: 0.3), color: .red),
                    Token(position: CGPoint(x: -0.55, y: 0.05), color: .red),
                    Token(position: CGPoint(x: 0.2, y: -0.35), color: .blue),
                    Token(position: CGPoint(x: 0.7, y: 0.25), color: .blue),
                    Token(position: CGPoint(x: 0.45, y: -0.05), color: .blue)
                ],
                startRotation: 1.2,
                startOffset: CGVector(dx: -0.60, dy: 0.40)
            ),
            Level(
                id: "stars-horseshoe",
                title: "Horseshoe Stars",
                goal: .tokensPerSide(2),
                shapes: [Polygon([
                    CGPoint(x: -0.9, y: -0.9), CGPoint(x: 0.9, y: -0.9), CGPoint(x: 0.9, y: -0.45),
                    CGPoint(x: -0.35, y: -0.45), CGPoint(x: -0.35, y: 0.45), CGPoint(x: 0.9, y: 0.45),
                    CGPoint(x: 0.9, y: 0.9), CGPoint(x: -0.9, y: 0.9)
                ])],
                tokens: [
                    Token(position: CGPoint(x: -0.6, y: -0.7), color: .star),
                    Token(position: CGPoint(x: 0.4, y: -0.7), color: .star),
                    Token(position: CGPoint(x: -0.6, y: 0.7), color: .star),
                    Token(position: CGPoint(x: 0.4, y: 0.7), color: .star)
                ],
                startRotation: -0.2
            )
        ],
        starsToUnlock: 22
    )

    /// More than one cut, and a goal that only the finished pieces can answer.
    ///
    /// Two straight cuts through everything on the board make three pieces when they run
    /// parallel and four when they cross, so these levels are about planning both cuts, not
    /// about hitting one number twice.
    static let mosaic = Pack(
        id: "mosaic",
        title: "Mosaic",
        subtitle: "Cut it into pieces",
        levels: [
            Level(
                id: "mosaic-thirds",
                title: "Thirds",
                goal: .shares([1.0 / 3, 1.0 / 3, 1.0 / 3]),
                cuts: 2,
                shapes: [.rectangle(CGRect(x: -1, y: -0.5, width: 2, height: 1))],
                startOffset: CGVector(dx: 0.80, dy: 0)
            ),
            Level(
                id: "mosaic-quarters",
                title: "Quarters",
                goal: .shares([0.25, 0.25, 0.25, 0.25]),
                cuts: 2,
                shapes: [.regular(sides: 4, radius: 1)],
                startRotation: 0.5,
                startOffset: CGVector(dx: -0.70, dy: 0.20)
            ),
            Level(
                id: "mosaic-uneven",
                title: "Uneven",
                goal: .shares([0.5, 0.3, 0.2]),
                cuts: 2,
                shapes: [.regular(sides: 16, radius: 0.9)],
                startOffset: CGVector(dx: -0.90, dy: 0.40)
            ),
            Level(
                id: "mosaic-ell",
                title: "Split Elbow",
                goal: .shares([1.0 / 3, 1.0 / 3, 1.0 / 3]),
                cuts: 2,
                shapes: [Polygon([
                    CGPoint(x: -0.9, y: -0.9), CGPoint(x: 0.3, y: -0.9), CGPoint(x: 0.3, y: -0.2),
                    CGPoint(x: 0.9, y: -0.2), CGPoint(x: 0.9, y: 0.9), CGPoint(x: -0.9, y: 0.9)
                ])],
                startRotation: 0.8,
                startOffset: CGVector(dx: 0.70, dy: -0.20)
            ),
            Level(
                id: "mosaic-hexagon",
                title: "Three Ways",
                goal: .shares([0.5, 1.0 / 3, 1.0 / 6]),
                cuts: 2,
                shapes: [.regular(sides: 6, radius: 0.95)],
                startRotation: 0.2,
                startOffset: CGVector(dx: -0.80, dy: 0)
            )
        ],
        starsToUnlock: 37
    )

    // MARK: - Hand-drawn shapes

    private static let pear = Polygon((0..<26).map { index in
        let angle = Double(index) / 26 * 2 * .pi
        // A circle that swells at the bottom and pinches at the top.
        let radius = 0.55 + 0.32 * sin(angle + .pi / 2) * sin(angle + .pi / 2)
        return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius * 1.25)
    })

    private static let crescent = Polygon(
        (0...16).map { index -> CGPoint in
            let angle = .pi * 0.15 + Double(index) / 16 * .pi * 1.2
            return CGPoint(x: cos(angle), y: sin(angle))
        } + (0...16).reversed().map { index -> CGPoint in
            let angle = .pi * 0.15 + Double(index) / 16 * .pi * 1.2
            return CGPoint(x: cos(angle) * 0.62, y: sin(angle) * 0.62 - 0.18)
        }
    )

    private static let apple = Polygon((0..<28).map { index in
        let angle = Double(index) / 28 * 2 * .pi
        // Two lobes on top, a point at the bottom.
        let radius = 0.82 + 0.12 * cos(angle * 2) - 0.1 * sin(angle)
        return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
    })
}
