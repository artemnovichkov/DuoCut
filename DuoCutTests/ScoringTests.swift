import CoreGraphics
import Foundation
import Testing

@testable import DuoCut

@Suite("Scoring")
struct ScoringTests {
    private let fold = FoldLine(line: .vertical(x: 200), thickness: 20, isReserved: true)

    @Test func sharesAreJudgedOnThePiecesNotTheCuts() {
        let level = Level(
            id: "thirds",
            title: "Thirds",
            goal: .shares([1.0 / 3, 1.0 / 3, 1.0 / 3]),
            cuts: 2,
            shapes: [.rectangle(CGRect(x: -1, y: -1, width: 2, height: 2))]
        )
        #expect(level.judge(areas: [100, 100, 100]).stars == 3)
        #expect(level.judge(areas: [104, 100, 96]).stars < 3)
        // Two cuts down the same line leave two pieces, which is not an answer at all.
        let halves = level.judge(areas: [150, 150])
        #expect(halves.stars == 0)
        #expect(halves.detail.contains("need 3"))
    }

    @Test func unevenSharesMatchLargestFirst() {
        let level = Level(
            id: "uneven",
            title: "Uneven",
            goal: .shares([0.5, 0.3, 0.2]),
            cuts: 2,
            shapes: [.regular(sides: 16, radius: 1)]
        )
        #expect(level.judge(areas: [20, 50, 30]).stars == 3)
        #expect(level.judge(areas: [50, 50, 0.0001]).stars == 0)
    }

    @Test func mirroredCutsScoreTheSame() {
        let level = Level(id: "third", title: "A Third", goal: .ratio(1.0 / 3), shapes: [.regular(sides: 12, radius: 1)])
        let oneWay = CutBoard.Outcome(positiveArea: 1.0 / 3, negativeArea: 2.0 / 3)
        let other = CutBoard.Outcome(positiveArea: 2.0 / 3, negativeArea: 1.0 / 3)
        #expect(level.judge(oneWay).stars == 3)
        #expect(level.judge(other).stars == 3)
        // The stats agree with the stars: both are a perfect cut.
        #expect((level.areaError(for: oneWay) ?? 1) < 0.002)
        #expect((level.areaError(for: other) ?? 1) < 0.002)
    }

    @Test func tokenGoalsGiveCreditForOneStrayToken() {
        let level = Level(
            id: "four",
            title: "Four",
            goal: .tokensPerSide(2),
            shapes: [.regular(sides: 20, radius: 1)]
        )
        let star = { (x: Double) in Token(position: CGPoint(x: x, y: 0), color: .star) }
        let even = CutBoard.Outcome(
            positiveArea: 1, negativeArea: 1,
            positiveTokens: [star(1), star(2)], negativeTokens: [star(-1), star(-2)]
        )
        let offByOne = CutBoard.Outcome(
            positiveArea: 1, negativeArea: 1,
            positiveTokens: [star(1), star(2), star(3)], negativeTokens: [star(-1)]
        )
        #expect(level.judge(even).stars == 3)
        #expect(level.judge(offByOne).stars == 1)
        #expect(level.areaError(for: even) == nil)
    }

    @Test func fractionsReadAsWords() {
        #expect(Level(id: "a", title: "", goal: .ratio(1.0 / 3), shapes: []).instruction == "Cut off a third")
        #expect(Level(id: "b", title: "", goal: .ratio(0.25), shapes: []).instruction == "Cut off a quarter")
        #expect(Level(id: "c", title: "", goal: .ratio(0.4), shapes: []).instruction == "Cut off 40%")
        #expect(Level(id: "d", title: "", goal: .shares([0.5, 0.5]), shapes: []).instruction == "2 equal pieces")
    }

    @Test func aLevelNeverOpensOnTheBlade() {
        let level = Level(
            id: "square",
            title: "Square",
            goal: .equalHalves,
            shapes: [.rectangle(CGRect(x: -0.8, y: -0.8, width: 1.6, height: 1.6))]
        )
        let size = CGSize(width: 400, height: 600)
        let placed = level.placed(in: size, fold: fold).shapes
        let cut = PolygonCut.split(placed[0], by: fold.line)
        #expect(!cut.isCut)
    }

    @Test func aPlacedLevelStaysOnTheBoard() {
        let level = Level(
            id: "big",
            title: "Big",
            goal: .equalHalves,
            shapes: [.regular(sides: 6, radius: 1)],
            startOffset: CGVector(dx: 4, dy: 0)
        )
        let size = CGSize(width: 400, height: 600)
        let box = level.placed(in: size, fold: fold).shapes[0].boundingBox
        #expect(box.midX > 0)
        #expect(box.midX < size.width)
    }
}
