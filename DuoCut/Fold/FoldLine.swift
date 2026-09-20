import SwiftUI

/// Where the blade is: the fold, in the coordinate space of a `GeometryProxy`.
///
/// The system reports the fold as a `.division` reserved region. It's only active while the
/// device is partially folded, so the query asks for inactive regions too — otherwise the blade
/// would disappear on a flat device, exactly when the player is lining a shape up.
/// Regions can arrive after the first layout pass, so read this inside a `GeometryReader` body
/// and never cache it.
struct FoldLine: Equatable {
    /// Which way the fold runs across the screen.
    enum Axis {
        case vertical, horizontal
    }

    /// Which side of the fold something sits on. `.before` is left of a vertical fold and
    /// above a horizontal one.
    enum Side {
        case before, after
    }

    /// The cut line itself.
    var line: Line
    /// How wide the reserved region is. The blade is drawn this wide when the fold is real.
    var thickness: Double
    /// `false` when there's no hinge and the line is just the middle of the view.
    var isReserved: Bool

    // 👇 The API: the fold, as a rectangle the system asks us to keep clear.
    static func from(_ proxy: GeometryProxy) -> FoldLine {
        let region = proxy.reservedRegions(kind: .division, options: [.includeInactive]).first
        guard let frame = region?.frame else {
            return FoldLine(line: .vertical(x: proxy.size.width / 2), thickness: 0, isReserved: false)
        }
        if frame.height >= frame.width {
            return FoldLine(line: .vertical(x: frame.midX), thickness: frame.width, isReserved: true)
        }
        return FoldLine(line: .horizontal(y: frame.midY), thickness: frame.height, isReserved: true)
    }

    var axis: Axis { line.direction.dx == 0 ? .vertical : .horizontal }

    /// The two points where the line leaves `size`, for drawing.
    func endpoints(in size: CGSize) -> (CGPoint, CGPoint) {
        let span = max(size.width, size.height) * 2
        return (line.point(at: -span), line.point(at: span))
    }

    // MARK: - Keeping things off the crease

    /// The part of a board of `size` on one side of the fold, with the reserved band left out.
    func half(_ side: Side, in size: CGSize) -> CGRect {
        let gap = thickness / 2
        switch (axis, side) {
        case (.vertical, .before):
            return CGRect(x: 0, y: 0, width: max(0, line.point.x - gap), height: size.height)
        case (.vertical, .after):
            let start = min(size.width, line.point.x + gap)
            return CGRect(x: start, y: 0, width: max(0, size.width - start), height: size.height)
        case (.horizontal, .before):
            return CGRect(x: 0, y: 0, width: size.width, height: max(0, line.point.y - gap))
        case (.horizontal, .after):
            let start = min(size.height, line.point.y + gap)
            return CGRect(x: 0, y: start, width: size.width, height: max(0, size.height - start))
        }
    }

    /// How wide a half is across the fold.
    func room(_ side: Side, in size: CGSize) -> Double {
        let rect = half(side, in: size)
        return axis == .vertical ? rect.width : rect.height
    }

    /// The side with more room. A fold dead in the middle is a tie, and ties go to `tieBreak`.
    func roomier(in size: CGSize, tieBreak: Side = .after) -> Side {
        let before = room(.before, in: size)
        let after = room(.after, in: size)
        guard abs(before - after) > 1 else { return tieBreak }
        return before > after ? .before : .after
    }

    /// Moves a view centred in `size` into the middle of one half, so the crease misses it.
    /// Stays put when there's no fold, or when the half is narrower than `minimum`.
    func offset(into side: Side, in size: CGSize, minimum: Double = 0) -> CGSize {
        guard isReserved, room(side, in: size) >= minimum else { return .zero }
        let rect = half(side, in: size)
        guard rect.width > 0, rect.height > 0 else { return .zero }
        return axis == .vertical
            ? CGSize(width: rect.midX - size.width / 2, height: 0)
            : CGSize(width: 0, height: rect.midY - size.height / 2)
    }

    /// Moves a view centred in `size` into whichever half has more room.
    func offsetIntoRoomierHalf(in size: CGSize, minimum: Double = 0) -> CGSize {
        offset(into: roomier(in: size), in: size, minimum: minimum)
    }
}
