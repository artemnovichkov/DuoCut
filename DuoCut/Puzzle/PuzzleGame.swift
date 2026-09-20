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
    /// The worst cut so far in a multi-cut level.
    private var running: Judgement?
    private var size = CGSize.zero

    var level: Level { pack.levels[index] }
    var isLastLevel: Bool { index == pack.levels.count - 1 }
    /// Multi-cut levels keep the halves on the board.
    var keepsPieces: Bool { level.cuts > 1 }

    init(pack: Pack = Levels.basics, index: Int = 0) {
        self.pack = pack
        self.index = index
        cutsLeft = pack.levels[index].cuts
    }

    func layout(for newSize: CGSize) {
        guard newSize != size else { return }
        size = newSize
        if phase == .aiming, board.isEmpty || board.cuts == 0 { start() }
    }

    func start() {
        guard size != .zero else { return }
        let placed = level.placed(in: size)
        board.place(placed.shapes, tokens: placed.tokens)
        cutsLeft = level.cuts
        running = nil
        phase = .aiming
    }

    func record(_ outcome: CutBoard.Outcome) {
        let judgement = level.judge(outcome)
        running = running.map { $0.stars <= judgement.stars ? $0 : judgement } ?? judgement
        cutsLeft -= 1
        guard cutsLeft <= 0, let final = running else { return }
        progress.record(final.stars, for: level)
        phase = .judged(final)
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
