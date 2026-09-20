import SwiftUI

/// Flat, calm, high contrast: paper, ink, and one accent.
enum Palette {
    static let paper = Color(red: 0.97, green: 0.95, blue: 0.91)
    static let ink = Color(red: 0.13, green: 0.13, blue: 0.15)
    static let blade = Color(red: 0.91, green: 0.42, blue: 0.36)
    static let shape = Color(red: 0.42, green: 0.56, blue: 0.86)
    static let shapeAlternate = Color(red: 0.95, green: 0.74, blue: 0.36)
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
