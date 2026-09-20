import Foundation
import Observation

/// Everything the game remembers about the player across both modes.
///
/// It's also where achievements are decided: every recorded event re-checks the list and
/// hands back whatever just unlocked, so the views only have to show a toast.
@Observable
final class PlayerStats {
    /// Hinge snaps, ever. The number the game likes to remind you about.
    private(set) var folds: Int
    private(set) var cuts: Int
    /// Cuts that landed inside a tenth of a percent of the goal.
    private(set) var perfectCuts: Int
    private(set) var bestCombo: Int
    private(set) var bestArcadeScore: Int
    private(set) var unlocked: Set<String>
    /// The achievement to show in a toast, if any.
    var latest: Achievement?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        folds = defaults.integer(forKey: "stats.folds")
        cuts = defaults.integer(forKey: "stats.cuts")
        perfectCuts = defaults.integer(forKey: "stats.perfect")
        bestCombo = defaults.integer(forKey: "arcade.combo")
        bestArcadeScore = defaults.integer(forKey: "arcade.best")
        unlocked = Set(defaults.stringArray(forKey: "stats.achievements") ?? [])
        // Stars, packs and the daily streak live with the progress that owns them, so they
        // are read back here rather than kept twice. Without this an achievement for stars
        // earned last week could only unlock after another level in this session.
        let progress = PuzzleProgress(defaults: defaults)
        stars = progress.total
        completedPacks = Levels.packs.count { progress.stars(in: $0) == $0.levels.count * 3 }
        dailyStreak = defaults.integer(forKey: "daily.streak")
        check(announce: false)
    }

    // MARK: - Events

    /// Every snap of the hinge, whether or not it hit anything.
    func recordFold() {
        folds += 1
        defaults.set(folds, forKey: "stats.folds")
        check()
    }

    /// A cut that landed. `error` says how far off an area goal it was, from 0 to 1, and is
    /// `nil` for the goals that aren't about area — those can't be a perfect 50.0 / 50.0.
    func recordCut(error: Double?) {
        cuts += 1
        defaults.set(cuts, forKey: "stats.cuts")
        if let error, error < 0.002 {
            perfectCuts += 1
            defaults.set(perfectCuts, forKey: "stats.perfect")
        }
        check()
    }

    func recordArcade(score: Int, combo: Int) {
        bestArcadeScore = max(bestArcadeScore, score)
        bestCombo = max(bestCombo, combo)
        check()
    }

    func recordPuzzle(progress: PuzzleProgress) {
        stars = progress.total
        completedPacks = Levels.packs.count { progress.stars(in: $0) == $0.levels.count * 3 }
        check()
    }

    func recordDaily(streak: Int) {
        dailyStreak = max(dailyStreak, streak)
        check()
    }

    private(set) var stars = 0
    private(set) var completedPacks = 0
    private(set) var dailyStreak = 0

    // MARK: - Achievements

    func isUnlocked(_ achievement: Achievement) -> Bool {
        unlocked.contains(achievement.id)
    }

    /// `announce` is off when catching up on what the player already earned, so starting the
    /// app doesn't fire a stack of toasts for old news.
    private func check(announce: Bool = true) {
        for achievement in Achievement.all where !unlocked.contains(achievement.id) && achievement.isEarned(self) {
            unlocked.insert(achievement.id)
            if announce { latest = achievement }
        }
        defaults.set(Array(unlocked), forKey: "stats.achievements")
    }
}

/// One thing worth bragging about.
struct Achievement: Identifiable, Equatable {
    var id: String
    var title: String
    var detail: String
    var symbol: String
    /// Whether the stats already earn it.
    var isEarned: (PlayerStats) -> Bool

    static func == (lhs: Achievement, rhs: Achievement) -> Bool { lhs.id == rhs.id }

    static let all: [Achievement] = [
        Achievement(id: "first-cut", title: "First Cut", detail: "Cut a shape in two", symbol: "scissors") { $0.cuts >= 1 },
        Achievement(id: "perfect", title: "Dead Even", detail: "Split a shape 50.0 / 50.0", symbol: "equal.circle") { $0.perfectCuts >= 1 },
        Achievement(id: "perfect-10", title: "Steady Hand", detail: "Ten perfect cuts", symbol: "hand.raised") { $0.perfectCuts >= 10 },
        Achievement(id: "combo-3", title: "Double Take", detail: "Cut three shapes in one snap", symbol: "square.stack") { $0.bestCombo >= 3 },
        Achievement(id: "combo-5", title: "Fruit Salad", detail: "Cut five shapes in one snap", symbol: "sparkles") { $0.bestCombo >= 5 },
        Achievement(id: "arcade-50", title: "Fast Blade", detail: "Score 50 in Arcade", symbol: "bolt") { $0.bestArcadeScore >= 50 },
        Achievement(id: "pack-clear", title: "Full Marks", detail: "Three stars on a whole pack", symbol: "star.square") { $0.completedPacks >= 1 },
        Achievement(id: "stars-30", title: "Collector", detail: "Earn 30 stars", symbol: "star.circle") { $0.stars >= 30 },
        Achievement(id: "daily-7", title: "Regular", detail: "Seven days in a row", symbol: "calendar") { $0.dailyStreak >= 7 },
        Achievement(id: "folds-100", title: "Well Used", detail: "Fold the phone 100 times", symbol: "book.closed") { $0.folds >= 100 },
        Achievement(id: "folds-1000", title: "Warranty Voided", detail: "Fold the phone 1000 times", symbol: "exclamationmark.triangle") { $0.folds >= 1_000 }
    ]
}
