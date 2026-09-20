import CoreGraphics
import Foundation

/// A dot that rides along with the shape.
///
/// Levels use tokens for goals the area alone can't express: keep the reds apart from the
/// blues, or leave exactly one star on each side of the cut.
struct Token: Identifiable, Equatable {
    enum Color: Equatable, CaseIterable {
        case red, blue, star
    }

    let id = UUID()
    var position: CGPoint
    var color: Color

    static func == (lhs: Token, rhs: Token) -> Bool {
        lhs.id == rhs.id && lhs.position == rhs.position && lhs.color == rhs.color
    }
}
