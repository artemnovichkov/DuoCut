import SwiftUI

/// The arcade screen: shapes fly, the blade waits on the fold, and timing is everything.
struct ArcadeView: View {
    let stats: PlayerStats

    @State private var game = ArcadeGame()
    @State private var detector = CutDetector()
    @State private var hasHinge = false

    var body: some View {
        GeometryReader { proxy in
            let fold = FoldLine.from(proxy)

            TimelineView(.animation) { timeline in
                Canvas { context, _ in
                    for piece in game.pieces {
                        context.opacity = piece.opacity
                        context.fill(piece.polygon.path, with: .color(Palette.shape))
                    }
                    context.opacity = 1
                    for flyer in game.flyers {
                        let color = flyer.kind == .bomb ? Palette.ink : Palette.shape
                        context.fill(flyer.polygon.path, with: .color(color))
                        if flyer.kind == .bomb {
                            context.stroke(flyer.polygon.path, with: .color(Palette.blade), lineWidth: 4)
                        }
                    }
                }
                .onChange(of: timeline.date, initial: true) { _, date in
                    game.step(to: date)
                }
            }
            .background { FoldBand(fold: fold) }
            .overlay {
                BladeOverlay(fold: fold, tension: detector.tension)
            }
            .overlay { hud(in: proxy.size, fold: fold) }
            .contentShape(.rect)
            .onTapGesture {
                restartIfWelcome(size: proxy.size, fold: fold)
            }
            .gesture(swipeToCut(fold: fold))
            .onChange(of: fold, initial: true) { _, newFold in
                game.layout(for: proxy.size, fold: newFold)
            }
            .onChange(of: proxy.size) { _, size in
                game.layout(for: size, fold: fold)
            }
            .onChange(of: game.phase) { _, phase in
                guard phase == .over else { return }
                stats.recordArcade(score: game.score, combo: game.bestCombo)
            }
            // 👇 The API: the same snap as in Puzzle, but here it's about timing.
            .onHingeChange { _, newContext in
                hasHinge = newContext.hinge != nil
                guard let degrees = newContext.hinge?.angle.degrees else { return }
                if let snap = detector.update(degrees: degrees, at: Date.timeIntervalSinceReferenceDate) {
                    stats.recordFold()
                    // A snap starts the run as well as cutting, so the hinge is the only control.
                    if game.phase == .playing {
                        game.cut(with: fold.line, speed: snap.speed)
                    } else {
                        restartIfWelcome(size: proxy.size, fold: fold)
                    }
                }
            }
        }
        .background(Palette.paper)
        .ignoresSafeArea()
        .sensoryFeedback(.impact(weight: .heavy), trigger: game.hits)
        .sensoryFeedback(.error, trigger: game.phase) { _, phase in phase == .over }
        .achievementToast(stats)
        .onDisappear {
            // Walking out mid-run still banks the score.
            guard game.phase == .playing else { return }
            game.finish()
            stats.recordArcade(score: game.score, combo: game.bestCombo)
        }
    }

    /// A run starts from the welcome screen, or from a game over once it has settled.
    private func restartIfWelcome(size: CGSize, fold: FoldLine) {
        switch game.phase {
        case .ready:
            game.start(in: size, fold: fold)
        case .over where game.canRestart:
            game.start(in: size, fold: fold)
        default:
            break
        }
    }

    private func hud(in size: CGSize, fold: FoldLine) -> some View {
        VStack {
            HStack(alignment: .top) {
                Text(game.score, format: .number)
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(game.score)))
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: index < game.lives ? "heart.fill" : "heart")
                            .font(.system(size: 18))
                            .foregroundStyle(index < game.lives ? Palette.blade : Palette.ink.opacity(0.2))
                    }
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(.leading, 72)
            .padding(.trailing, 28)
            .padding(.top, 24)

            Spacer()

            middle
                // The banner and the combo count both sit in one half, clear of the crease.
                .offset(fold.axis == .vertical ? fold.offsetIntoRoomierHalf(in: size, minimum: 360) : .zero)

            Spacer()
        }
        .allowsHitTesting(false)
        .animation(.snappy, value: game.phase)
        .animation(.snappy, value: game.lastCombo)
    }

    @ViewBuilder
    private var middle: some View {
        switch game.phase {
        case .ready:
            banner(title: "Arcade", subtitle: hint)
        case .playing:
            if game.lastCombo > 1 {
                Text("×\(game.lastCombo)")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(Palette.blade)
                    .transition(.scale)
            }
        case .over:
            banner(title: "Game over", subtitle: overSubtitle)
        }
    }

    private func banner(title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(Palette.ink)
            Text(subtitle)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }

    private var hint: String {
        let start = hasHinge ? "Snap the hinge as a shape crosses the fold" : "Swipe across the line to cut"
        let best = game.best > 0 ? "\nBest \(game.best) · " : "\n"
        return start + best + (hasHinge ? "snap to start" : "tap to start")
    }

    private var overSubtitle: String {
        let score = "\(game.score) · best \(game.best)"
        guard game.canRestart else { return score }
        return score + (hasHinge ? "\nSnap or tap to play again" : "\nTap to play again")
    }

    /// The no-hinge fallback: a swipe across the blade fires the same cut.
    private func swipeToCut(fold: FoldLine) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let crossed = fold.line.signedDistance(to: value.startLocation)
                    * fold.line.signedDistance(to: value.location) < 0
                guard crossed else { return }
                game.cut(with: fold.line, speed: hypot(value.translation.width, value.translation.height))
            }
    }
}

#Preview {
    ArcadeView(stats: PlayerStats())
}
