import SwiftUI

/// Where the blade is: the fold, in the coordinate space of a `GeometryProxy`.
///
/// The system reports the fold as a `.division` reserved region. It's only active while the
/// device is partially folded, so the query asks for inactive regions too — otherwise the blade
/// would disappear on a flat device, exactly when the player is lining a shape up.
/// Regions can arrive after the first layout pass, so read this inside a `GeometryReader` body
/// and never cache it.
struct FoldLine: Equatable {
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

    /// The two points where the line leaves `size`, for drawing.
    func endpoints(in size: CGSize) -> (CGPoint, CGPoint) {
        let span = max(size.width, size.height) * 2
        return (line.point(at: -span), line.point(at: span))
    }
}
