import CoreGraphics
import Foundation

/// One authored puzzle: a shape, where it starts, and what a good cut means.
///
/// Shapes are written in unit space — roughly inside a circle of radius 1 around the origin —
/// so the same level fits the inner display, the outer one, and any pose in between. The
/// starting offset is in those same units, which keeps a level equally hard on both displays.
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
        /// The board should end up holding pieces with these shares of the whole, in any
        /// order. This is what a multi-cut level is judged on: the pieces, not the cuts.
        case shares([Double])
    }

    var id: String
    var title: String
    var goal: Goal
    /// How many cuts the player gets. Above one, the halves stay on the board.
    var cuts = 1
    var shapes: [Polygon]
    var tokens: [Token] = []
    /// Where the shape starts, in shape units, so no level opens already solved.
    var startRotation = 0.0
    var startOffset = CGVector(dx: 0, dy: 0)

    var instruction: String {
        switch goal {
        case .equalHalves: "Cut it in half"
        case .ratio(let share): "Cut off \(Self.fraction(share))"
        case .separateColors: "Reds on one side, blues on the other"
        case .tokensPerSide(let count): "\(count) on each side"
        case .shares(let shares): Self.pieces(shares)
        }
    }

    /// The target share of the whole the positive side should end up with.
    var target: Double {
        switch goal {
        case .equalHalves, .separateColors, .tokensPerSide: 0.5
        case .ratio(let share): share
        case .shares(let shares): shares.first ?? 0.5
        }
    }

    /// The level laid out in a board of `size`, clear of the blade.
    ///
    /// Centring the shape would drop it right on the fold, which is the answer to half the
    /// levels in the game. So the shape is shoved off the blade along the fold's normal,
    /// staying on the side the author picked and inside the board.
    func placed(in size: CGSize, fold: FoldLine) -> (shapes: [Polygon], tokens: [Token]) {
        let scale = scale(in: size, fold: fold)
        let center = CGPoint(
            x: size.width / 2 + startOffset.dx * scale,
            y: size.height / 2 + startOffset.dy * scale
        )
        let transform = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: startRotation)
            .scaledBy(x: scale, y: scale)
        let placed = shapes.map { $0.applying(transform) }
        let moved = tokens.map { token in
            var moved = token
            moved.position = token.position.applying(transform)
            return moved
        }
        let push = clearance(for: placed, of: fold, in: size)
        guard push != 0 else { return (placed, moved) }
        let offset = fold.axis == .vertical ? CGVector(dx: push, dy: 0) : CGVector(dx: 0, dy: push)
        return (
            placed.map { $0.translated(by: offset) },
            moved.map { token in
                var pushed = token
                pushed.position = CGPoint(x: token.position.x + offset.dx, y: token.position.y + offset.dy)
                return pushed
            }
        )
    }

    /// How big the shape is drawn.
    ///
    /// Big enough to fill the board, but never so big that it can't fit in one half of it:
    /// a shape wider than a half would start across the blade, which is half the answer on
    /// an even-halves level. The outer display is the narrow case that needs this.
    private func scale(in size: CGSize, fold: FoldLine) -> Double {
        let base = min(size.width, size.height) * 0.28
        let reach = shapes.flatMap(\.vertices).map { hypot($0.x, $0.y) }.max() ?? 1
        let room = min(fold.room(.before, in: size), fold.room(.after, in: size))
        guard reach > 0, room > 0 else { return base }
        return min(base, max(base * 0.55, (room - 28) / (2 * reach)))
    }

    /// How far, and which way, the shape has to move to sit clear of the blade.
    private func clearance(for shapes: [Polygon], of fold: FoldLine, in size: CGSize) -> Double {
        guard var box = shapes.first?.boundingBox else { return 0 }
        for shape in shapes.dropFirst() { box = box.union(shape.boundingBox) }
        let isVertical = fold.axis == .vertical
        let reach = (isVertical ? box.width : box.height) / 2
        let span = isVertical ? size.width : size.height
        let middle = isVertical ? box.midX : box.midY
        let blade = isVertical ? fold.line.point.x : fold.line.point.y
        let side: Double = middle < blade ? -1 : 1
        // Whatever else happens, the shape has to be on the board and grabbable.
        let lower = reach + 12
        let upper = max(lower, span - reach - 12)
        let onBoard = min(max(middle, lower), upper)
        // And clear of the blade, on the side the author picked, as far as the board allows.
        let clear = reach + fold.thickness / 2 + 24
        guard abs(onBoard - blade) < clear else { return onBoard - middle }
        let wanted = blade + side * clear
        return min(max(wanted, lower), upper) - middle
    }

    private static func fraction(_ share: Double) -> String {
        let names = [2: "half", 3: "a third", 4: "a quarter", 5: "a fifth", 6: "a sixth", 8: "an eighth"]
        let rounded = Int((1 / share).rounded())
        if abs(1 / share - Double(rounded)) < 0.01, let name = names[rounded] { return name }
        return "\(Int((share * 100).rounded()))%"
    }

    private static func pieces(_ shares: [Double]) -> String {
        let first = shares.first ?? 0
        if shares.allSatisfy({ abs($0 - first) < 0.001 }) {
            return "\(shares.count) equal pieces"
        }
        return "Pieces: " + shares
            .sorted(by: >)
            .map { "\(Int(($0 * 100).rounded()))%" }
            .joined(separator: " · ")
    }
}

/// How well a cut met the goal.
struct Judgement: Equatable {
    var stars: Int
    /// The line under the stars: the split, or what went wrong.
    var detail: String

    var isSuccess: Bool { stars > 0 }

    /// The headline on the result card, honest about how good the cut was.
    var title: String {
        switch stars {
        case 3: "Dead on"
        case 2: "Close"
        case 1: "It'll do"
        default: "Off the mark"
        }
    }
}

extension Level {
    /// Scores a single cut against this level's goal. Multi-piece goals are scored with
    /// `judge(areas:)` instead, once the last cut has landed.
    func judge(_ outcome: CutBoard.Outcome) -> Judgement {
        switch goal {
        case .equalHalves, .ratio, .shares:
            let error = areaError(for: outcome) ?? 1
            let percent = (min(outcome.share, 1 - outcome.share) * 100)
            let split = percent.formatted(.number.precision(.fractionLength(1)))
            let other = (100 - percent).formatted(.number.precision(.fractionLength(1)))
            return Judgement(stars: Self.stars(for: error), detail: "\(split)% / \(other)%")
        case .separateColors:
            // One token on the wrong side still earns something: the cut was nearly there.
            let stray = Token.Color.allCases.reduce(0) { total, color in
                let positive = outcome.positiveTokens.count { $0.color == color }
                let negative = outcome.negativeTokens.count { $0.color == color }
                return total + min(positive, negative)
            }
            let split = !outcome.positiveTokens.isEmpty && !outcome.negativeTokens.isEmpty
            guard split else { return Judgement(stars: 0, detail: "All on one side") }
            switch stray {
            case 0: return Judgement(stars: 3, detail: "Sorted")
            case 1: return Judgement(stars: 1, detail: "One on the wrong side")
            default: return Judgement(stars: 0, detail: "\(stray) on the wrong side")
            }
        case .tokensPerSide(let count):
            let positive = outcome.positiveTokens.count
            let negative = outcome.negativeTokens.count
            let off = abs(positive - count) + abs(negative - count)
            let detail = "\(positive) and \(negative), need \(count) and \(count)"
            switch off {
            case 0: return Judgement(stars: 3, detail: "\(count) and \(count)")
            case ...2: return Judgement(stars: 1, detail: detail)
            default: return Judgement(stars: 0, detail: detail)
            }
        }
    }

    /// Scores the pieces left on the board against a `.shares` goal.
    ///
    /// Cuts aren't scored one by one here: two cuts down the same line would each look like a
    /// reasonable split while leaving the wrong pieces behind. What counts is the set of
    /// pieces at the end, matched to the target set largest first.
    func judge(areas: [Double]) -> Judgement {
        guard case .shares(let targets) = goal else {
            return Judgement(stars: 0, detail: "No cut")
        }
        let total = areas.reduce(0, +)
        guard total > 0 else { return Judgement(stars: 0, detail: "No cut") }
        let actual = areas.map { $0 / total }.sorted(by: >)
        let wanted = targets.sorted(by: >)
        let detail = actual
            .map { "\(Int(($0 * 100).rounded()))%" }
            .joined(separator: " · ")
        guard actual.count == wanted.count else {
            let pieces = actual.count == 1 ? "1 piece" : "\(actual.count) pieces"
            return Judgement(stars: 0, detail: "\(pieces), need \(wanted.count)")
        }
        let worst = zip(actual, wanted)
            .map { abs($0 - $1) / max($1, 1 - $1) }
            .max() ?? 1
        return Judgement(stars: Self.stars(for: worst), detail: detail)
    }

    /// How far a single cut was from an area goal, from 0 to 1, or `nil` when the goal isn't
    /// about area at all. A cut and its mirror image are equally good, so both are checked.
    func areaError(for outcome: CutBoard.Outcome) -> Double? {
        switch goal {
        case .equalHalves, .ratio:
            return min(outcome.error(against: target), outcome.error(against: 1 - target))
        case .separateColors, .tokensPerSide, .shares:
            return nil
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
