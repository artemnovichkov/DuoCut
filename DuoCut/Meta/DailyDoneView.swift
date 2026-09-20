import SwiftUI

/// Today's cut is already in the books.
///
/// The daily counts once, so opening it again shouldn't hand the player a board that quietly
/// throws the result away. This shows what they got, the streak it belongs to, and the last
/// week of days.
struct DailyDoneView: View {
    let daily: DailyStore
    let record: DailyStore.Record

    var body: some View {
        GeometryReader { proxy in
            let fold = FoldLine.from(proxy)
            card
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(fold.axis == .vertical ? fold.offsetIntoRoomierHalf(in: proxy.size, minimum: 400) : .zero)
        }
        .background(Palette.paper)
    }

    private var card: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text(DailyChallenge.title())
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.45))
                    .textCase(.uppercase)
                Text("Today's cut")
                    .font(.system(size: 30, weight: .black, design: .rounded))
            }
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < record.stars ? "star.fill" : "star")
                        .font(.system(size: 28))
                        .foregroundStyle(index < record.stars ? Palette.shapeAlternate : Palette.ink.opacity(0.18))
                }
            }
            Text(record.detail)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if daily.streak > 1 {
                Text("\(daily.streak) day streak")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.5))
            }
            history
            ShareLink(item: daily.shareText(for: record)) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.paper)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Palette.ink, in: .capsule)
            }
            Text("New shape tomorrow")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.4))
        }
        .foregroundStyle(Palette.ink)
        .padding(32)
        .background(Palette.ink.opacity(0.04), in: .rect(cornerRadius: 28))
        .padding(32)
    }

    /// The last week as a row of scores, newest on the left.
    @ViewBuilder
    private var history: some View {
        let days = daily.recent
        if days.count > 1 {
            HStack(spacing: 10) {
                ForEach(days) { day in
                    VStack(spacing: 4) {
                        Text("\(day.day % 100)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Palette.ink.opacity(0.4))
                        Circle()
                            .fill(day.stars > 0 ? Palette.shapeAlternate.opacity(0.35 + 0.22 * Double(day.stars)) : Palette.ink.opacity(0.12))
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(.top, 4)
        }
    }
}
