import CoreGraphics
import Foundation

/// One authored puzzle: a shape, where it starts, and what a good cut means.
///
/// Shapes are written in unit space — roughly inside a circle of radius 1 around the origin —
/// so the same level fits the inner display, the outer one, and any pose in between.
struct Level: Identifiable, Equatable {
    enum Goal: Equatable {
        /// Two halves of the same size.
        case equalHalves
        /// One side gets this share of the shape, for example a third.
        case ratio(Double)
        /// Every red token on one side, every blue one on the other.
        case separateColors
        /// This many tokens on each side.
        case tokensPerSide(Int)
    }

    var id: String
    var title: String
    var goal: Goal
    /// How many cuts the player gets. Above one, the halves stay on the board.
    var cuts = 1
    var shapes: [Polygon]
    var tokens: [Token] = []
    /// Where the shape starts, so no level opens already solved.
    var startRotation = 0.0
    var startOffset = CGVector(dx: 0, dy: 0)

    var instruction: String {
        switch goal {
        case .equalHalves: "Cut it in half"
        case .ratio(let share): "Cut off \(Self.fraction(share))"
        case .separateColors: "Reds on one side, blues on the other"
        case .tokensPerSide(let count): "\(count) on each side"
        }
    }

    /// The target share of the whole the positive side should end up with.
    var target: Double {
        switch goal {
        case .equalHalves, .separateColors, .tokensPerSide: 0.5
        case .ratio(let share): share
        }
    }

    /// The level laid out in a board of `size`.
    func placed(in size: CGSize) -> (shapes: [Polygon], tokens: [Token]) {
        let scale = min(size.width, size.height) * 0.28
        let center = CGPoint(x: size.width / 2 + startOffset.dx, y: size.height / 2 + startOffset.dy)
        let transform = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: startRotation)
            .scaledBy(x: scale, y: scale)
        return (
            shapes.map { $0.applying(transform) },
            tokens.map { token in
                var moved = token
                moved.position = token.position.applying(transform)
                return moved
            }
        )
    }

    private static func fraction(_ share: Double) -> String {
        let rounded = (1 / share).rounded()
        return abs(1 / share - rounded) < 0.01 ? "a \(Int(rounded))th" : "\(Int((share * 100).rounded()))%"
    }
}

/// How well a cut met the goal.
struct Judgement: Equatable {
    var stars: Int
    /// The line under the stars: the split, or what went wrong.
    var detail: String

    var isSuccess: Bool { stars > 0 }
}

extension Level {
    /// Scores a cut against this level's goal.
    func judge(_ outcome: CutBoard.Outcome) -> Judgement {
        switch goal {
        case .equalHalves, .ratio:
            let error = min(outcome.error(against: target), outcome.error(against: 1 - target))
            let percent = (min(outcome.share, 1 - outcome.share) * 100)
            let split = percent.formatted(.number.precision(.fractionLength(1)))
            return Judgement(stars: Self.stars(for: error), detail: "\(split)% / \((100 - percent).formatted(.number.precision(.fractionLength(1))))%")
        case .separateColors:
            let positive = Set(outcome.positiveTokens.map(\.color))
            let negative = Set(outcome.negativeTokens.map(\.color))
            let separated = !positive.isEmpty && !negative.isEmpty && positive.isDisjoint(with: negative)
            return Judgement(stars: separated ? 3 : 0, detail: separated ? "Sorted" : "Still mixed")
        case .tokensPerSide(let count):
            let matched = outcome.positiveTokens.count == count && outcome.negativeTokens.count == count
            return Judgement(
                stars: matched ? 3 : 0,
                detail: "\(outcome.positiveTokens.count) and \(outcome.negativeTokens.count)"
            )
        }
    }

    private static func stars(for error: Double) -> Int {
        switch error {
        case ..<0.02: 3
        case ..<0.05: 2
        case ..<0.12: 1
        default: 0
        }
    }
}
