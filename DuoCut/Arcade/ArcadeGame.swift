import CoreGraphics
import Foundation
import Observation

/// Shapes fly across the fold; snap the hinge as one crosses it.
///
/// One snap cuts everything touching the blade at that instant, so the timing — not the aim —
/// is what the player is practicing. Bombs end the run, and fruit that falls back out costs
/// a life.
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

    private let gravity = 900.0
    private var size = CGSize.zero
    private var lastDate: Date?
    private var nextSpawn = 0.0
    private var time = 0.0

    /// Seconds between throws, tightening as the score climbs.
    private var spawnInterval: Double { max(0.55, 1.5 - Double(score) * 0.02) }

    func start(in newSize: CGSize) {
        size = newSize
        flyers = []
        pieces = []
        score = 0
        lives = 3
        lastCombo = 0
        time = 0
        nextSpawn = 0.2
        phase = .playing
    }

    func layout(for newSize: CGSize) {
        size = newSize
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
            return
        }

        let fallen = flyers.filter { $0.hasFallen(below: size.height + 120) }
        flyers.removeAll { $0.hasFallen(below: size.height + 120) }
        for flyer in fallen where flyer.kind == .fruit {
            lives -= 1
        }
        if lives <= 0 { end() }

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
        if hitBomb { end() }
    }

    private func end() {
        phase = .over
        if score > best {
            best = score
            UserDefaults.standard.set(best, forKey: "arcade.best")
        }
    }

    /// Throws one shape up across the fold, so it crosses the blade near the top of its arc.
    private func spawn() {
        let isBomb = score >= 6 && Double.random(in: 0...1) < 0.16
        let radius = Double.random(in: 34...52)
        let fromLeft = Bool.random()
        let startX = fromLeft ? Double.random(in: 0.08...0.3) : Double.random(in: 0.7...0.92)
        let start = CGPoint(x: size.width * startX, y: size.height + radius)
        // Aim the arc at the middle of the screen, where the fold is.
        let rise = Double.random(in: 0.55...0.78) * size.height
        let upward = -sqrt(2 * gravity * rise)
        let timeToApex = -upward / gravity
        let targetX = size.width * Double.random(in: 0.42...0.58)
        let sideways = (targetX - start.x) / timeToApex

        let shape: Polygon = isBomb
            ? .regular(sides: 8, radius: radius * 0.9, center: start)
            : .regular(sides: Int.random(in: 5...9), radius: radius, center: start, rotation: .random(in: 0...2))
        flyers.append(Flyer(
            polygon: shape,
            velocity: CGVector(dx: sideways, dy: upward),
            spin: .random(in: -1.6...1.6),
            kind: isBomb ? .bomb : .fruit
        ))
    }
}
