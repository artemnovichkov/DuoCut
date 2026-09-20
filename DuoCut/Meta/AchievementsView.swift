import SwiftUI

/// The full list, with the locked ones greyed out, and the fold counter at the bottom.
struct AchievementsView: View {
    let stats: PlayerStats

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Achievement.all) { achievement in
                    row(achievement)
                }
                FoldCounter(folds: stats.folds)
                    .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.paper)
        .scrollContentBackground(.hidden)
    }

    private func row(_ achievement: Achievement) -> some View {
        let isUnlocked = stats.isUnlocked(achievement)
        return HStack(spacing: 14) {
            Image(systemName: achievement.symbol)
                .font(.system(size: 20))
                .frame(width: 44, height: 44)
                .background(isUnlocked ? Palette.blade.opacity(0.14) : Palette.ink.opacity(0.05), in: .circle)
                .foregroundStyle(isUnlocked ? Palette.blade : Palette.ink.opacity(0.3))
            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Text(achievement.detail)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.5))
            }
            Spacer()
        }
        .foregroundStyle(isUnlocked ? Palette.ink : Palette.ink.opacity(0.45))
        .padding(14)
        .background(Palette.ink.opacity(0.04), in: .rect(cornerRadius: 18))
    }
}

/// The joke the press wrote for us: how many folds this game has cost the hinge.
struct FoldCounter: View {
    let folds: Int

    var body: some View {
        VStack(spacing: 4) {
            Text(folds, format: .number)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .monospacedDigit()
            Text(folds == 1 ? "fold so far" : "folds so far")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.45))
        }
        .foregroundStyle(Palette.ink)
    }
}

/// The banner that slides in when something unlocks.
struct AchievementToast: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.symbol)
                .font(.system(size: 18))
                .foregroundStyle(Palette.blade)
            VStack(alignment: .leading, spacing: 1) {
                Text(achievement.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text(achievement.detail)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.5))
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Palette.paper, in: .capsule)
        .shadow(color: Palette.ink.opacity(0.15), radius: 18, y: 6)
    }
}

extension View {
    /// Shows each new achievement for a moment, then clears it.
    func achievementToast(_ stats: PlayerStats) -> some View {
        overlay(alignment: .bottom) {
            if let achievement = stats.latest {
                AchievementToast(achievement: achievement)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: achievement.id) {
                        try? await Task.sleep(for: .seconds(2.5))
                        withAnimation(.snappy) { stats.latest = nil }
                    }
            }
        }
        .animation(.snappy, value: stats.latest)
    }
}
