import SwiftUI

/// Pick a pack. Later packs stay shut until enough stars are in.
struct PackListView: View {
    let progress: PuzzleProgress
    var onPick: (Pack) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(Levels.packs) { pack in
                    row(pack)
                }
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.paper)
        .scrollContentBackground(.hidden)
    }

    private func row(_ pack: Pack) -> some View {
        let stars = progress.stars(in: pack)
        let isOpen = progress.total >= pack.starsToUnlock
        return Button {
            onPick(pack)
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(pack.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(isOpen ? pack.subtitle : "\(pack.starsToUnlock) stars to open")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Palette.ink.opacity(0.5))
                }
                Spacer()
                if isOpen {
                    Label("\(stars)/\(pack.levels.count * 3)", systemImage: "star.fill")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.shapeAlternate)
                } else {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(Palette.ink.opacity(0.25))
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(18)
            .background(Palette.ink.opacity(0.04), in: .rect(cornerRadius: 20))
            .opacity(isOpen ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!isOpen)
    }
}
