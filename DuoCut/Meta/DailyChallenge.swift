import CoreGraphics
import Foundation
import Observation

/// One shape a day, the same for everyone, one cut to get it even.
enum DailyChallenge {
    /// The day number the game counts by, so a date turns into a seed and a title.
    static func day(for date: Date = .now, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return (components.year ?? 0) * 10_000 + (components.month ?? 0) * 100 + (components.day ?? 0)
    }

    static func level(for date: Date = .now) -> Level {
        let number = day(for: date)
        var random = SeededGenerator(seed: UInt64(number))
        let shape = shape(with: &random)
        return Level(
            id: "daily-\(number)",
            title: title(for: date),
            // A symmetric shape cut in half is no puzzle at all — line it up with the fold
            // and you're done — so those days ask for a fraction instead.
            goal: shape.isSymmetric
                ? (Bool.random(using: &random) ? .ratio(1.0 / 3) : .ratio(0.25))
                : (Bool.random(using: &random) ? .equalHalves : .ratio(1.0 / 3)),
            shapes: [shape.polygon],
            startRotation: .random(in: 0..<(2 * .pi), using: &random),
            // In shape units, and well off to one side: the day starts with work to do.
            startOffset: CGVector(
                dx: (Bool.random(using: &random) ? 1 : -1) * .random(in: 0.6...1.2, using: &random),
                dy: .random(in: -0.4...0.4, using: &random)
            )
        )
    }

    /// What the day is called on screen and on the share card.
    static func title(for date: Date = .now) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    /// A regular shape, a star, or a lumpy blob — whatever the day's seed says. The blob is
    /// the only one that's lopsided, and the goal is picked to match.
    private static func shape(with random: inout SeededGenerator) -> (polygon: Polygon, isSymmetric: Bool) {
        switch Int.random(in: 0..<3, using: &random) {
        case 0:
            return (.regular(sides: .random(in: 3...9, using: &random), radius: 0.9), true)
        case 1:
            return (
                .star(
                    points: .random(in: 5...8, using: &random),
                    outerRadius: 1,
                    innerRadius: .random(in: 0.35...0.6, using: &random)
                ),
                true
            )
        default:
            let count = Int.random(in: 7...11, using: &random)
            let radii = (0..<count).map { _ in Double.random(in: 0.55...1, using: &random) }
            let blob = Polygon(radii.enumerated().map { index, radius in
                let angle = Double(index) / Double(count) * 2 * .pi
                return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            })
            return (blob, false)
        }
    }
}

/// Deterministic randomness, so everyone gets the same shape on the same day.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        // SplitMix64.
        state &+= 0x9E37_79B9_7F4A_7C15
        var result = state
        result = (result ^ (result >> 30)) &* 0xBF58_476D_1CE4_E5B9
        result = (result ^ (result >> 27)) &* 0x94D0_49BB_1331_11EB
        return result ^ (result >> 31)
    }
}

/// The daily result, the streak, and the last few days.
@Observable
final class DailyStore {
    struct Record: Codable, Identifiable {
        var day: Int
        var stars: Int
        var detail: String

        var id: Int { day }
    }

    private(set) var history: [Record]
    private(set) var streak: Int

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.data(forKey: "daily.history") ?? Data()
        history = (try? JSONDecoder().decode([Record].self, from: stored)) ?? []
        streak = defaults.integer(forKey: "daily.streak")
    }

    func record(for date: Date = .now) -> Record? {
        let today = DailyChallenge.day(for: date)
        return history.first { $0.day == today }
    }

    /// The last week, newest first, for the done screen.
    var recent: [Record] {
        history.suffix(7).reversed()
    }

    /// What goes out to a chat when there's no fresh cut to draw a card from.
    func shareText(for record: Record, date: Date = .now) -> String {
        var line = "DuoCut \(DailyChallenge.title(for: date)) · \(record.detail)"
        line += " · \(String(repeating: "★", count: record.stars))\(String(repeating: "☆", count: 3 - record.stars))"
        if streak > 1 { line += " · \(streak) day streak" }
        return line
    }

    /// Today counts once. A later cut doesn't replace the first one.
    func record(_ judgement: Judgement, for date: Date = .now, calendar: Calendar = .current) {
        let today = DailyChallenge.day(for: date)
        guard record(for: date) == nil else { return }
        let yesterday = DailyChallenge.day(
            for: calendar.date(byAdding: .day, value: -1, to: date) ?? date,
            calendar: calendar
        )
        streak = history.contains { $0.day == yesterday } ? streak + 1 : 1
        history.append(Record(day: today, stars: judgement.stars, detail: judgement.detail))
        history = history.suffix(30)
        defaults.set(streak, forKey: "daily.streak")
        defaults.set(try? JSONEncoder().encode(history), forKey: "daily.history")
    }
}
