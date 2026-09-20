import SwiftUI

/// The puzzle screen: the shape, the blade, the live split, and the result card.
struct PuzzleView: View {
    @State var game: PuzzleGame
    let stats: PlayerStats
    /// Set for the daily challenge, which records a streak and offers a share card.
    var daily: DailyStore?

    @State private var fold: FoldLine?

    var body: some View {
        GeometryReader { proxy in
            CutBoardView(
                board: game.board,
                keepPieces: game.keepsPieces,
                onCut: { outcome in
                    stats.recordCut(error: outcome.error(against: game.level.target))
                    withAnimation(.snappy) { game.record(outcome) }
                    if case .judged(let judgement) = game.phase {
                        stats.recordPuzzle(progress: game.progress)
                        if let daily {
                            daily.record(judgement)
                            stats.recordDaily(streak: daily.streak)
                        }
                    }
                },
                onFoldChange: { fold = $0 },
                onSnap: { stats.recordFold() }
            )
            .onChange(of: proxy.size, initial: true) { _, size in
                game.layout(for: size)
            }
            .overlay(alignment: .top) {
                header
                    .padding(.top, headerPadding(in: proxy))
            }
            .overlay {
                if case .judged(let judgement) = game.phase {
                    ResultCard(
                        game: game,
                        judgement: judgement,
                        daily: daily,
                        retry: { withAnimation(.snappy) { game.retry() } },
                        next: { withAnimation(.snappy) { game.next() } }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .background(Palette.paper)
        .ignoresSafeArea()
        .achievementToast(stats)
    }

    /// The title block sits clear of the fold: above a horizontal division, at the top otherwise.
    private func headerPadding(in proxy: GeometryProxy) -> Double {
        guard let fold, fold.isReserved, fold.line.direction.dx != 0 else { return 44 }
        return max(24, fold.line.point.y / 2 - 40)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(subtitle)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.45))
                .textCase(.uppercase)
            Text(game.level.instruction)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
            split
        }
        .multilineTextAlignment(.center)
        .allowsHitTesting(false)
    }

    private var subtitle: String {
        if daily != nil { return game.level.title }
        return "\(game.level.title) · \(game.index + 1)/\(game.pack.levels.count)"
    }

    /// The live split, so the player can aim before the snap.
    @ViewBuilder
    private var split: some View {
        if case .aiming = game.phase, let fold, let outcome = game.board.preview(with: fold.line), outcome.isCutting {
            Text(percent(outcome.share) + " / " + percent(1 - outcome.share))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.blade)
                .padding(.top, 2)
        }
    }

    private func percent(_ value: Double) -> String {
        (value * 100).formatted(.number.precision(.fractionLength(1))) + "%"
    }
}

/// What the cut turned out to be, with a way on.
private struct ResultCard: View {
    let game: PuzzleGame
    let judgement: Judgement
    let daily: DailyStore?
    let retry: () -> Void
    let next: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < judgement.stars ? "star.fill" : "star")
                        .font(.system(size: 30))
                        .foregroundStyle(index < judgement.stars ? Palette.shapeAlternate : Palette.ink.opacity(0.18))
                }
            }
            VStack(spacing: 4) {
                Text(judgement.isSuccess ? "Clean cut" : "Off the mark")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(judgement.detail)
                    .font(.system(size: 17, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink.opacity(0.55))
            }
            HStack(spacing: 12) {
                if daily == nil {
                    Button("Again", action: retry)
                        .buttonStyle(CardButton(isProminent: !judgement.isSuccess))
                    if judgement.isSuccess {
                        Button(game.isLastLevel ? "Start over" : "Next", action: next)
                            .buttonStyle(CardButton(isProminent: true))
                    }
                }
                share
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(28)
        .background(Palette.paper, in: .rect(cornerRadius: 28))
        .shadow(color: Palette.ink.opacity(0.12), radius: 30, y: 8)
        .padding(32)
    }

    @ViewBuilder
    private var share: some View {
        if let image = card.rendered() {
            ShareLink(item: image, preview: SharePreview(shareTitle, image: image)) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(CardButton(isProminent: daily != nil))
        }
    }

    private var shareTitle: String {
        daily != nil ? "DuoCut Daily" : "DuoCut · \(game.level.title)"
    }

    private var card: ShareCard {
        ShareCard(
            title: shareTitle,
            shapes: game.board.lastCutShapes,
            line: game.board.lastCutLine,
            detail: judgement.detail,
            stars: judgement.stars,
            streak: daily?.streak
        )
    }
}

private struct CardButton: ButtonStyle {
    var isProminent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(isProminent ? Palette.paper : Palette.ink)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(isProminent ? Palette.ink : Palette.ink.opacity(0.08), in: .capsule)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

#Preview {
    PuzzleView(game: PuzzleGame(), stats: PlayerStats())
}
