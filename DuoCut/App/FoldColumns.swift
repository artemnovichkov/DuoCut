import SwiftUI

/// A list that keeps itself off the crease.
///
/// On the inner display the fold runs down the middle of a wide screen, so a single centred
/// column would be split in two by it. This lays the rows out as two columns instead, one in
/// each half, with the reserved region as the gutter. Narrow screens, and screens where the
/// fold runs the other way, get the usual single column.
struct FoldColumns<Item: Identifiable, Row: View, Detail: View>: View {
    let title: String
    let items: [Item]
    @ViewBuilder var row: (Item) -> Row
    /// Sits under the title, where it can't be clipped by the bottom of a full list.
    @ViewBuilder var detail: () -> Detail

    /// Below this width two columns would be too cramped to read.
    private let widthForTwoColumns = 760.0

    var body: some View {
        GeometryReader { proxy in
            let fold = FoldLine.from(proxy)
            let isSplit = fold.axis == .vertical && proxy.size.width >= widthForTwoColumns
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(Palette.ink)
                        detail()
                    }
                    .frame(maxWidth: isSplit ? .infinity : nil, alignment: isSplit ? .center : .leading)
                    if isSplit {
                        HStack(alignment: .top, spacing: max(32, fold.thickness + 32)) {
                            column(Array(items.prefix(halfCount)))
                            column(Array(items.dropFirst(halfCount)))
                        }
                    } else {
                        column(items)
                    }
                }
                // Clear of the back button in the top-left corner.
                .padding(.top, 64)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .frame(maxWidth: isSplit ? .infinity : 560)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Palette.paper)
    }

    private var halfCount: Int {
        (items.count + 1) / 2
    }

    private func column(_ items: [Item]) -> some View {
        VStack(spacing: 12) {
            ForEach(items) { row($0) }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

extension FoldColumns where Detail == EmptyView {
    init(title: String, items: [Item], @ViewBuilder row: @escaping (Item) -> Row) {
        self.init(title: title, items: items, row: row, detail: { EmptyView() })
    }
}
