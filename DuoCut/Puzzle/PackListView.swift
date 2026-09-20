import SwiftUI

/// Pick a pack. Later packs stay shut until enough stars are in.
struct PackListView: View {
    let progress: PuzzleProgress
    var onPick: (Pack) -> Void

    var body: some View {
        FoldColumns(title: "Puzzle", items: Levels.packs) { pack in
            row(pack)
        }
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
                        .foregroundStyle(Palette.ink.opacity(0.55))
                }
                Spacer()
                if isOpen {
                    Label("\(stars)/\(pack.levels.count * 3)", systemImage: "star.fill")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.shapeAlternate)
                } else {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(Palette.ink.opacity(0.4))
                }
            }
            .foregroundStyle(isOpen ? Palette.ink : Palette.ink.opacity(0.75))
            .padding(18)
            .background(Palette.ink.opacity(isOpen ? 0.06 : 0.03), in: .rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .disabled(!isOpen)
    }
}
