import CoreGraphics
import Foundation
import Observation

/// Shapes fly across the fold; snap the hinge as one crosses it.
///
/// One snap cuts everything touching the blade at that instant, so the timing — not the aim —
/// is what the player is practicing. Shapes come in bursts and meet the blade a little before
/// or after the top of their arc, which is what makes a combo something you can aim for
/// rather than a coincidence. Bombs end the run, and fruit that falls back out costs a life.
@Observable
final class ArcadeGame {
    enum Phase: Equatable {
        case ready, playing, over
    }

    private(set) var phase = Phase.ready
    private(set) var flyers: [Flyer] = []
    private(set) var pieces: [Piece] = []
    private(set) var score = 0
    private(set) var best = UserDefaults.standard.integer(forKey: "arcade.best")
    private(set) var lives = 3
    /// How many fruit the last snap took, for the combo banner.
    private(set) var lastCombo = 0
    private(set) var bestCombo = UserDefaults.standard.integer(forKey: "arcade.combo")
    /// Counts snaps that connected, for haptics.
    private(set) var hits = 0
    /// A game over holds still for a moment, so the tap that ended it doesn't start the next run.
    private(set) var canRestart = false

    private let gravity = 900.0
    /// Fruit missed in the first seconds is free: a run shouldn't be over before it starts.
    private let grace = 4.0
    private var size = CGSize.zero
    private var fold: FoldLine?
    private var lastDate: Date?
    private var nextSpawn = 0.0
    private var time = 0.0
    private var endedAt: Double?

    /// Seconds between bursts, tightening as the score climbs.
    private var spawnInterval: Double { max(0.7, 1.6 - Double(score) * 0.012) }

    func layout(for newSize: CGSize, fold newFold: FoldLine) {
        size = newSize
        self.fold = newFold
    }

    func start(in newSize: CGSize, fold newFold: FoldLine) {
        size = newSize
        fold = newFold
        flyers = []
        pieces = []
        score = 0
        lives = 3
        lastCombo = 0
        time = 0
        endedAt = nil
        canRestart = false
        nextSpawn = 0.4
        phase = .playing
    }

    func step(to date: Date) {
        let dt = lastDate.map { min(date.timeIntervalSince($0), 1.0 / 30) } ?? 0
        lastDate = date
        guard dt > 0, size.height > 0 else { return }
        time += dt

        for index in pieces.indices { pieces[index].step(dt, gravity: gravity) }
        pieces.removeAll { $0.isGone }

        for index in flyers.indices { flyers[index].step(dt, gravity: gravity) }
        // After a game over the throws still land; they just don't cost anything.
        guard phase == .playing else {
            flyers.removeAll { $0.hasFallen(below: size.height + 120) }
            if let endedAt, time - endedAt > 0.8 { canRestart = true }
            return
        }

        let fallen = flyers.filter { $0.hasFallen(below: size.height + 120) }
        flyers.removeAll { $0.hasFallen(below: size.height + 120) }
        if time > grace {
            for flyer in fallen where flyer.kind == .fruit {
                lives -= 1
            }
        }
        if lives <= 0 { finish() }

        nextSpawn -= dt
        if nextSpawn <= 0 {
            spawn()
            nextSpawn = spawnInterval
        }
    }

    /// Cuts everything the blade is touching right now.
    func cut(with line: Line, speed: Double) {
        guard phase == .playing else { return }
        var combo = 0
        var hitBomb = false
        var remaining: [Flyer] = []
        for flyer in flyers {
            let result = PolygonCut.split(flyer.polygon, by: line)
            guard result.isCut else {
                remaining.append(flyer)
                continue
            }
            if flyer.kind == .bomb { hitBomb = true }
            combo += flyer.kind == .fruit ? 1 : 0
            let launch = min(max(speed * 0.5, 120), 380)
            for polygon in result.positive + result.negative {
                var piece = Piece(polygon: polygon, line: line, speed: launch, spin: .random(in: 0.8...2.6))
                // Cut pieces keep the throw they were already on.
                piece.velocity.dx += flyer.velocity.dx
                piece.velocity.dy += flyer.velocity.dy
                pieces.append(piece)
            }
        }
        flyers = remaining
        guard combo > 0 || hitBomb else { return }
        hits += 1
        lastCombo = combo
        score += combo * combo
        if combo > bestCombo {
            bestCombo = combo
            UserDefaults.standard.set(bestCombo, forKey: "arcade.combo")
        }
        if hitBomb { finish() }
    }

    /// Ends the run and banks the score. Also called when the player walks out mid-game.
    func finish() {
        guard phase == .playing else { return }
        phase = .over
        endedAt = time
        if score > best {
            best = score
            UserDefaults.standard.set(best, forKey: "arcade.best")
        }
    }

    // MARK: - Throwing

    /// One burst, aimed so its shapes meet the blade within a fraction of a second of each
    /// other. That's the window a combo lives in.
    private func spawn() {
        guard let fold, size.height > 0 else { return }
        let crossing = Double.random(in: 0.85...1.35)
        for index in 0..<burstSize() {
            launch(fold: fold, crossing: crossing + Double(index) * 0.1 + .random(in: -0.08...0.08))
        }
    }

    private func burstSize() -> Int {
        let extra = min(2, score / 18)
        let pair = Double.random(in: 0...1) < 0.5 ? 1 : 0
        return 1 + pair + extra
    }

    /// Throws one shape so that it crosses the blade — wherever the blade actually is —
    /// `crossing` seconds from now.
    private func launch(fold: FoldLine, crossing: Double) {
        let reach = min(max(min(size.width, size.height) * 0.055, 34), 88)
        let radius = reach * Double.random(in: 0.85...1.15)
        let isBomb = score >= 8 && Double.random(in: 0...1) < 0.14
        let start: CGPoint
        let velocity: CGVector

        switch fold.axis {
        case .vertical:
            let fromLeft = Bool.random()
            let startX = size.width * (fromLeft ? .random(in: 0.06...0.28) : .random(in: 0.72...0.94))
            start = CGPoint(x: startX, y: size.height + radius)
            let rise = Double.random(in: 0.58...0.82) * size.height
            let upward = -sqrt(2 * gravity * rise)
            let flight = -2 * upward / gravity
            let meet = min(max(crossing, 0.25), max(0.3, flight - 0.2))
            let target = fold.line.point.x + Double.random(in: -0.04...0.04) * size.width
            velocity = CGVector(dx: (target - startX) / meet, dy: upward)
        case .horizontal:
            // The blade lies across the screen, so anything thrown up has to cross it. The
            // arc only needs to clear the line for the shape to come back through.
            let startX = size.width * Double.random(in: 0.12...0.88)
            start = CGPoint(x: startX, y: size.height + radius)
            let clearance = Double.random(in: 0.12...0.3) * size.height
            let rise = max(size.height - fold.line.point.y + clearance, 0.4 * size.height)
            let upward = -sqrt(2 * gravity * rise)
            let drift = Double.random(in: -0.18...0.18) * size.width
            velocity = CGVector(dx: drift / (-upward / gravity), dy: upward)
        }

        let shape: Polygon = isBomb
            ? .regular(sides: 8, radius: radius * 0.9, center: start)
            : .regular(sides: Int.random(in: 5...9), radius: radius, center: start, rotation: .random(in: 0...2))
        flyers.append(Flyer(
            polygon: shape,
            velocity: velocity,
            spin: .random(in: -1.6...1.6),
            kind: isBomb ? .bomb : .fruit
        ))
    }
}
