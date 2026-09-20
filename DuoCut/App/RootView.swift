import SwiftUI

/// The menu: the daily cut, the packs, the arcade, and what you've unlocked.
struct RootView: View {
    private enum Screen: String, Identifiable {
        case daily, puzzle, arcade, achievements
        var id: String { rawValue }
    }

    /// `-mode daily`, `puzzle`, `arcade`, or `achievements` opens a screen straight away,
    /// which is how the simulator runs one screen without tapping through the menu.
    @State private var screen = Screen(rawValue: UserDefaults.standard.string(forKey: "mode") ?? "")
    @State private var pack: Pack?
    @State private var stats = PlayerStats()
    @State private var daily = DailyStore()

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .daily:
            PuzzleView(game: PuzzleGame(pack: dailyPack), stats: stats, daily: daily)
                .overlay(alignment: .topLeading) { backButton }
        case .puzzle:
            if let pack {
                PuzzleView(game: PuzzleGame(pack: pack), stats: stats)
                    .overlay(alignment: .topLeading) { backButton }
            } else {
                PackListView(progress: PuzzleProgress()) { self.pack = $0 }
                    .overlay(alignment: .topLeading) { backButton }
            }
        case .arcade:
            ArcadeView(stats: stats)
                .overlay(alignment: .topLeading) { backButton }
        case .achievements:
            AchievementsView(stats: stats)
                .overlay(alignment: .topLeading) { backButton }
        case nil:
            menu
        }
    }

    /// Today's shape, wrapped in a pack of one.
    private var dailyPack: Pack {
        Pack(id: "daily", title: "Daily", subtitle: "One shape a day", levels: [DailyChallenge.level()])
    }

    private var menu: some View {
        VStack(spacing: 30) {
            VStack(spacing: 10) {
                Text("DuoCut")
                    .font(.system(size: 60, weight: .black, design: .rounded))
                Text("Line the shape up with the fold.\nSnap the hinge to cut it.")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 14) {
                tile("Daily", dailySubtitle, .daily)
                tile("Puzzle", "Aim, then snap", .puzzle)
                tile("Arcade", "Snap on time", .arcade)
            }
            Button {
                screen = .achievements
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rosette")
                    Text("\(stats.unlocked.count) of \(Achievement.all.count) unlocked · \(stats.folds) folds")
                }
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Palette.ink)
    }

    private var dailySubtitle: String {
        if let record = daily.record() {
            return "Done · \(record.detail)"
        }
        return daily.streak > 0 ? "\(daily.streak) day streak" : "One cut a day"
    }

    private func tile(_ title: String, _ subtitle: String, _ value: Screen) -> some View {
        Button {
            screen = value
        } label: {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.45))
                    .multilineTextAlignment(.center)
            }
            .frame(width: 160, height: 110)
            .background(Palette.ink.opacity(0.06), in: .rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.ink)
    }

    private var backButton: some View {
        Button {
            if screen == .puzzle, pack != nil {
                pack = nil
            } else {
                screen = nil
            }
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.ink.opacity(0.5))
                .frame(width: 44, height: 44)
        }
        .padding(.leading, 8)
        .padding(.top, 8)
    }
}

#Preview {
    RootView()
}
