import SwiftUI

/// A bare board to shake the cut down on: one shape, one blade, one snap.
/// The mode menu replaces it once Puzzle and Arcade exist.
struct RootView: View {
    @State private var board = CutBoard()

    var body: some View {
        GeometryReader { proxy in
            CutBoardView(board: board)
                .onAppear {
                    place(in: proxy.size)
                }
                .onTapGesture(count: 2) {
                    place(in: proxy.size)
                }
        }
        .background(Palette.paper)
        .ignoresSafeArea()
    }

    private func place(in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        board.place(.regular(sides: 6, radius: min(size.width, size.height) * 0.22, center: center))
    }
}

#Preview {
    RootView()
}
