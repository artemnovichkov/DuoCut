import SwiftUI

/// Flat, calm, high contrast: paper, ink, and one accent.
///
/// The colours live in the asset catalog so they have a dark variant: paper turns to night,
/// ink to chalk, and the accents brighten a touch. Everything else in the game is built out
/// of `ink` at some opacity, so the whole app follows along.
enum Palette {
    static let paper = Color("Paper")
    static let ink = Color("Ink")
    static let blade = Color("Blade")
    static let shape = Color("Shape")
    static let shapeAlternate = Color("ShapeAlternate")

    /// A neighbouring piece, one shade apart, so a board of cut pieces doesn't read as one blob.
    static func piece(_ index: Int) -> Color {
        index.isMultiple(of: 2) ? shape : shape.opacity(0.72)
    }
}

extension Polygon {
    /// The polygon as a closed `Path`, ready to draw.
    var path: Path {
        var path = Path()
        guard let first = vertices.first else { return path }
        path.move(to: first)
        for vertex in vertices.dropFirst() { path.addLine(to: vertex) }
        path.closeSubpath()
        return path
    }
}
