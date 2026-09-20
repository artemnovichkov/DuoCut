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
    /// `-pack basics` opens a pack without going through the list.
    @State private var pack = Levels.packs.first { $0.id == UserDefaults.standard.string(forKey: "pack") }
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
            // The daily counts once a day, so a day that's already played shows its result
            // instead of a board whose cut would be thrown away.
            if let record = daily.record() {
                DailyDoneView(daily: daily, record: record)
                    .overlay(alignment: .topLeading) { backButton }
            } else {
                PuzzleView(game: PuzzleGame(pack: dailyPack), stats: stats, daily: daily)
                    .overlay(alignment: .topLeading) { backButton }
            }
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

    /// The menu keeps off the crease too: on a wide inner display the title takes one half and
    /// the modes the other, instead of a row of tiles with the fold through the middle one.
    private var menu: some View {
        GeometryReader { proxy in
            let fold = FoldLine.from(proxy)
            let isSplit = fold.isReserved && fold.axis == .vertical && proxy.size.width >= 760
            Group {
                if isSplit {
                    HStack(spacing: max(32, fold.thickness + 32)) {
                        title
                            .frame(maxWidth: .infinity)
                        VStack(spacing: 12) {
                            tiles(isWide: true)
                            unlockedButton
                                .padding(.top, 6)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 40)
                } else {
                    VStack(spacing: 30) {
                        title
                        tiles(isWide: false)
                        unlockedButton
                    }
                    .padding(.horizontal, 24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(Palette.ink)
        }
    }

    private var title: some View {
        VStack(spacing: 10) {
            Text("DuoCut")
                .font(.system(size: 60, weight: .black, design: .rounded))
            Text("Line the shape up with the fold.\nSnap the hinge to cut it.")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func tiles(isWide: Bool) -> some View {
        let items = [
            ("Daily", dailySubtitle, Screen.daily),
            ("Puzzle", "Aim, then snap", Screen.puzzle),
            ("Arcade", "Snap on time", Screen.arcade)
        ]
        if isWide {
            VStack(spacing: 12) {
                ForEach(items, id: \.2) { tile($0.0, $0.1, $0.2, isWide: true) }
            }
        } else {
            HStack(spacing: 14) {
                ForEach(items, id: \.2) { tile($0.0, $0.1, $0.2, isWide: false) }
            }
        }
    }

    private var unlockedButton: some View {
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

    private var dailySubtitle: String {
        if let record = daily.record() {
            return "Done · \(record.detail)"
        }
        return daily.streak > 0 ? "\(daily.streak) day streak" : "One cut a day"
    }

    private func tile(_ title: String, _ subtitle: String, _ value: Screen, isWide: Bool) -> some View {
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
            .padding(.horizontal, 16)
            .frame(maxWidth: isWide ? 280 : 170)
            .frame(minWidth: isWide ? 220 : 130, minHeight: isWide ? 86 : 110)
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
