import Foundation

/// Stars per level, kept between launches.
struct PuzzleProgress {
    private static let key = "puzzle.stars"

    private(set) var stars: [String: Int]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        stars = defaults.dictionary(forKey: Self.key) as? [String: Int] ?? [:]
    }

    private let defaults: UserDefaults

    func stars(for level: Level) -> Int { stars[level.id] ?? 0 }

    var total: Int { stars.values.reduce(0, +) }

    func stars(in pack: Pack) -> Int {
        pack.levels.reduce(0) { $0 + stars(for: $1) }
    }

    /// Only ever improves a level's score.
    mutating func record(_ count: Int, for level: Level) {
        guard count > stars(for: level) else { return }
        stars[level.id] = count
        defaults.set(stars, forKey: Self.key)
    }
}
