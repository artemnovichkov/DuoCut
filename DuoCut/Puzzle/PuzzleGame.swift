import CoreGraphics
import Foundation
import Observation

/// Runs a pack: places each level on the board, scores the cuts, and keeps the stars.
@Observable
final class PuzzleGame {
    enum Phase: Equatable {
        case aiming
        case judged(Judgement)
    }

    let board = CutBoard()
    private(set) var pack: Pack
    private(set) var index: Int
    private(set) var phase = Phase.aiming
    private(set) var cutsLeft: Int
    private(set) var progress = PuzzleProgress()
    /// Counts snaps that hit nothing, so the screen can say the blade missed.
    private(set) var misses = 0
    /// The worst cut so far in a multi-cut level scored cut by cut.
    private var running: Judgement?
    /// Cuts landed on the level in play, which is what stops a re-layout from resetting it.
    private var cutsMade = 0
    private var size = CGSize.zero
    private var fold: FoldLine?

    var level: Level { pack.levels[index] }
    var isLastLevel: Bool { index == pack.levels.count - 1 }
    /// Multi-cut levels keep the halves on the board.
    var keepsPieces: Bool { level.cuts > 1 }

    init(pack: Pack = Levels.basics, index: Int = 0) {
        self.pack = pack
        self.index = index
        cutsLeft = pack.levels[index].cuts
    }

    /// The board changed size or the device changed pose. Before the first cut that means
    /// re-placing the shape around the new blade; after it, the player's work is left alone.
    func layout(size newSize: CGSize, fold newFold: FoldLine) {
        guard newSize != size || newFold != fold else { return }
        size = newSize
        fold = newFold
        if phase == .aiming, cutsMade == 0 { start() }
    }

    func start() {
        guard size != .zero, let fold else { return }
        let placed = level.placed(in: size, fold: fold)
        board.place(placed.shapes, tokens: placed.tokens)
        cutsLeft = level.cuts
        cutsMade = 0
        running = nil
        phase = .aiming
    }

    /// The blade came down on nothing.
    func recordMiss() {
        misses += 1
    }

    func record(_ outcome: CutBoard.Outcome) {
        cutsMade += 1
        cutsLeft -= 1
        if case .shares = level.goal {
            // Judged on the pieces the board is left with, not on the cuts one by one.
            guard cutsLeft <= 0 else { return }
            finish(level.judge(areas: board.shapeAreas))
        } else {
            let judgement = level.judge(outcome)
            running = running.map { $0.stars <= judgement.stars ? $0 : judgement } ?? judgement
            guard cutsLeft <= 0, let final = running else { return }
            finish(final)
        }
    }

    private func finish(_ judgement: Judgement) {
        progress.record(judgement.stars, for: level)
        // Whatever is still on the board flies apart, so a multi-cut level ends with the
        // same payoff as a single one.
        if let line = board.lastCutLine { board.scatter(from: line, speed: 320) }
        phase = .judged(judgement)
    }

    func retry() {
        start()
    }

    func next() {
        guard !isLastLevel else {
            index = 0
            start()
            return
        }
        index += 1
        start()
    }
}
