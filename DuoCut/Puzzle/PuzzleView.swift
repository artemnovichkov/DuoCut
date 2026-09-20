import SwiftUI

/// The puzzle screen: the shape, the blade, and the result card.
///
/// Everything the player reads is laid out around the fold: on the inner display the crease
/// runs down the middle, so the title and the result card move into one half rather than
/// sitting on the seam.
struct PuzzleView: View {
    @State var game: PuzzleGame
    let stats: PlayerStats
    /// Set for the daily challenge, which records a streak and offers a share card.
    var daily: DailyStore?

    @State private var fold: FoldLine?
    @State private var hasHinge = false
    @State private var showMiss = false
    @AppStorage("puzzle.hintSeen") private var hintSeen = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            CutBoardView(
                board: game.board,
                keepPieces: game.keepsPieces,
                onCut: { record($0) },
                onMiss: { game.recordMiss() },
                onFoldChange: { newFold in
                    fold = newFold
                    game.layout(size: size, fold: newFold)
                },
                onSnap: { stats.recordFold() },
                onHinge: { hasHinge = $0 }
            )
            .onChange(of: size) { _, newSize in
                guard let fold else { return }
                game.layout(size: newSize, fold: fold)
            }
            .overlay(alignment: .top) {
                header
                    .padding(.top, headerPadding(in: size))
                    .offset(asideOffset(in: size))
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
                    .offset(cardOffset(in: size))
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottom) {
                note
                    .padding(.bottom, 36)
                    .offset(asideOffset(in: size))
            }
        }
        .background(Palette.paper)
        .ignoresSafeArea()
        .animation(.snappy, value: showMiss)
        .sensoryFeedback(.warning, trigger: game.misses)
        .onChange(of: game.misses) { _, _ in showMiss = true }
        .task(id: game.misses) {
            guard game.misses > 0 else { return }
            try? await Task.sleep(for: .seconds(2))
            showMiss = false
        }
        .achievementToast(stats)
    }

    private func record(_ outcome: CutBoard.Outcome) {
        hintSeen = true
        stats.recordCut(error: game.level.areaError(for: outcome))
        withAnimation(.snappy) { game.record(outcome) }
        if case .judged(let judgement) = game.phase {
            stats.recordPuzzle(progress: game.progress)
            if let daily {
                daily.record(judgement)
                stats.recordDaily(streak: daily.streak)
            }
        }
    }

    // MARK: - Laying out around the fold

    /// Above a horizontal fold the title sits in the upper half; otherwise it stays at the top.
    private func headerPadding(in size: CGSize) -> Double {
        guard let fold, fold.isReserved, fold.axis == .horizontal else { return 44 }
        return max(24, fold.line.point.y / 2 - 44)
    }

    /// Slides a centred label out of a vertical crease, into the half the shape didn't start
    /// in. The side comes from the level rather than from where the shape is right now, so
    /// the title doesn't hop across the screen while the player drags.
    private func asideOffset(in size: CGSize) -> CGSize {
        guard let fold, fold.axis == .vertical else { return .zero }
        let side: FoldLine.Side = game.level.startOffset.dx >= 0 ? .before : .after
        guard fold.room(side, in: size) >= 340 else {
            return fold.offsetIntoRoomierHalf(in: size, minimum: 340)
        }
        return fold.offset(into: side, in: size, minimum: 340)
    }

    private func cardOffset(in size: CGSize) -> CGSize {
        guard let fold else { return .zero }
        return fold.offsetIntoRoomierHalf(in: size, minimum: 400)
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
            if game.level.cuts > 1 {
                cutsLeft
            }
        }
        .multilineTextAlignment(.center)
        .allowsHitTesting(false)
    }

    /// One dot per cut, so a level with more than one says how many are left.
    private var cutsLeft: some View {
        HStack(spacing: 6) {
            ForEach(0..<game.level.cuts, id: \.self) { index in
                Circle()
                    .fill(index < game.cutsLeft ? Palette.blade : Palette.ink.opacity(0.18))
                    .frame(width: 9, height: 9)
            }
        }
        .padding(.top, 2)
    }

    private var subtitle: String {
        if daily != nil { return game.level.title }
        return "\(game.level.title) · \(game.index + 1)/\(game.pack.levels.count)"
    }

    /// The line along the bottom: what went wrong, or how to play at all.
    @ViewBuilder
    private var note: some View {
        if showMiss {
            capsule("The blade missed — line the shape up with it")
        } else if !hintSeen, game.phase == .aiming {
            capsule(hint)
        }
    }

    private var hint: String {
        let cut = hasHinge ? "snap the hinge to cut" : "swipe across the line to cut"
        return "Drag to aim, two fingers to turn · \(cut)"
    }

    private func capsule(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(Palette.ink.opacity(0.6))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Palette.ink.opacity(0.06), in: .capsule)
            .transition(.opacity)
            .allowsHitTesting(false)
    }
}

/// What the cut turned out to be, with a way on.
private struct ResultCard: View {
    let game: PuzzleGame
    let judgement: Judgement
    let daily: DailyStore?
    let retry: () -> Void
    let next: () -> Void

    /// Rendered once when the card appears: the share image is a 1320×1860 bitmap, and
    /// redrawing it on every layout pass shows up as a stutter.
    @State private var image: Image?

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
                Text(judgement.title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(judgement.detail)
                    .font(.system(size: 17, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink.opacity(0.55))
                if let daily {
                    Text(daily.streak > 1 ? "\(daily.streak) day streak · new shape tomorrow" : "New shape tomorrow")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.ink.opacity(0.45))
                        .padding(.top, 2)
                }
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
        .task {
            guard image == nil else { return }
            image = card.rendered()
        }
    }

    @ViewBuilder
    private var share: some View {
        if let image {
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
