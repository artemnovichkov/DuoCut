import SwiftUI

/// The menu: pick a mode.
struct RootView: View {
    private enum Mode: String, Identifiable {
        case puzzle, arcade
        var id: String { rawValue }
    }

    /// `-mode puzzle` or `-mode arcade` opens a mode straight away, which is how the
    /// simulator runs a single screen without tapping through the menu.
    @State private var mode = Mode(rawValue: UserDefaults.standard.string(forKey: "mode") ?? "")

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            switch mode {
            case .puzzle:
                PuzzleView()
                    .overlay(alignment: .topLeading) { backButton }
            case .arcade:
                ArcadeView()
                    .overlay(alignment: .topLeading) { backButton }
            case nil:
                menu
            }
        }
    }

    private var menu: some View {
        VStack(spacing: 32) {
            VStack(spacing: 10) {
                Text("DuoCut")
                    .font(.system(size: 60, weight: .black, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text("Line the shape up with the fold.\nSnap the hinge to cut it.")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 16) {
                modeButton("Puzzle", "Aim, then snap", .puzzle)
                modeButton("Arcade", "Snap on time", .arcade)
            }
        }
    }

    private func modeButton(_ title: String, _ subtitle: String, _ value: Mode) -> some View {
        Button {
            mode = value
        } label: {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.45))
            }
            .frame(width: 170, height: 110)
            .background(Palette.ink.opacity(0.06), in: .rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.ink)
    }

    private var backButton: some View {
        Button {
            mode = nil
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
