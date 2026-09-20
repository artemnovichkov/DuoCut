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
            .overlay {
                BladeOverlay(fold: fold, tension: detector.tension)
            }
            .overlay { hud }
            .contentShape(.rect)
            .onTapGesture {
                if game.phase != .playing { game.start(in: proxy.size) }
            }
            .gesture(swipeToCut(fold: fold))
            .onChange(of: proxy.size, initial: true) { _, size in
                game.layout(for: size)
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
                        game.start(in: proxy.size)
                    }
                }
            }
        }
        .background(Palette.paper)
        .ignoresSafeArea()
        .sensoryFeedback(.impact(weight: .heavy), trigger: game.hits)
        .sensoryFeedback(.error, trigger: game.phase) { _, phase in phase == .over }
        .achievementToast(stats)
    }

    private var hud: some View {
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
                banner(title: "Game over", subtitle: "Best \(game.best) · tap to play again")
            }
            Spacer()
        }
        .allowsHitTesting(false)
        .animation(.snappy, value: game.phase)
        .animation(.snappy, value: game.lastCombo)
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
        hasHinge ? "Snap the hinge as a shape crosses the fold" : "Swipe across the line to cut"
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
