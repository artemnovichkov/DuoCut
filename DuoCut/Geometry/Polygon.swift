import CoreGraphics
import Foundation

/// A simple closed polygon: vertices in order, no holes.
///
/// Everything the game cuts is one of these — level shapes, flying fruit, and the pieces
/// left over after a cut.
nonisolated struct Polygon: Equatable {
    var vertices: [CGPoint]

    init(_ vertices: [CGPoint]) {
        self.vertices = vertices
    }

    /// Twice the signed area: positive when the vertices wind one way, negative the other.
    /// Screen coordinates have y pointing down, so "positive" reads as clockwise on screen.
    var signedArea: Double {
        guard vertices.count > 2 else { return 0 }
        var sum = 0.0
        for index in vertices.indices {
            let current = vertices[index]
            let next = vertices[(index + 1) % vertices.count]
            sum += current.x * next.y - next.x * current.y
        }
        return sum / 2
    }

    var area: Double { abs(signedArea) }

    /// The area-weighted centroid, which is what the pieces spin around.
    var centroid: CGPoint {
        let doubleArea = signedArea * 2
        guard vertices.count > 2, abs(doubleArea) > .ulpOfOne else {
            guard !vertices.isEmpty else { return .zero }
            let x = vertices.reduce(0) { $0 + $1.x } / Double(vertices.count)
            let y = vertices.reduce(0) { $0 + $1.y } / Double(vertices.count)
            return CGPoint(x: x, y: y)
        }
        var x = 0.0
        var y = 0.0
        for index in vertices.indices {
            let current = vertices[index]
            let next = vertices[(index + 1) % vertices.count]
            let cross = current.x * next.y - next.x * current.y
            x += (current.x + next.x) * cross
            y += (current.y + next.y) * cross
        }
        return CGPoint(x: x / (3 * doubleArea), y: y / (3 * doubleArea))
    }

    var boundingBox: CGRect {
        guard let first = vertices.first else { return .zero }
        var box = CGRect(origin: first, size: .zero)
        for vertex in vertices.dropFirst() {
            box = box.union(CGRect(origin: vertex, size: .zero))
        }
        return box
    }

    func translated(by offset: CGVector) -> Polygon {
        Polygon(vertices.map { CGPoint(x: $0.x + offset.dx, y: $0.y + offset.dy) })
    }

    func rotated(by radians: Double, around center: CGPoint) -> Polygon {
        let cosine = cos(radians)
        let sine = sin(radians)
        return Polygon(vertices.map { vertex in
            let dx = vertex.x - center.x
            let dy = vertex.y - center.y
            return CGPoint(x: center.x + dx * cosine - dy * sine, y: center.y + dx * sine + dy * cosine)
        })
    }

    func scaled(by factor: Double, around center: CGPoint) -> Polygon {
        Polygon(vertices.map { vertex in
            CGPoint(x: center.x + (vertex.x - center.x) * factor, y: center.y + (vertex.y - center.y) * factor)
        })
    }

    func applying(_ transform: CGAffineTransform) -> Polygon {
        Polygon(vertices.map { $0.applying(transform) })
    }

    /// Even-odd ray casting, used for hit-testing a shape under the finger.
    func contains(_ point: CGPoint) -> Bool {
        guard vertices.count > 2 else { return false }
        var isInside = false
        var previous = vertices[vertices.count - 1]
        for current in vertices {
            let straddles = (current.y > point.y) != (previous.y > point.y)
            if straddles {
                let x = (previous.x - current.x) * (point.y - current.y) / (previous.y - current.y) + current.x
                if point.x < x { isInside.toggle() }
            }
            previous = current
        }
        return isInside
    }

    /// Drops vertices that repeat or sit on a straight run, so cut pieces stay tidy.
    func simplified(tolerance: Double = 1e-7) -> Polygon {
        var points: [CGPoint] = []
        for vertex in vertices where points.last.map({ hypot(vertex.x - $0.x, vertex.y - $0.y) > tolerance }) ?? true {
            points.append(vertex)
        }
        if points.count > 1, let first = points.first, let last = points.last,
           hypot(first.x - last.x, first.y - last.y) <= tolerance {
            points.removeLast()
        }
        guard points.count > 2 else { return Polygon(points) }
        var kept: [CGPoint] = []
        for index in points.indices {
            let previous = points[(index - 1 + points.count) % points.count]
            let current = points[index]
            let next = points[(index + 1) % points.count]
            let cross = (current.x - previous.x) * (next.y - previous.y) - (current.y - previous.y) * (next.x - previous.x)
            if abs(cross) > tolerance { kept.append(current) }
        }
        return Polygon(kept.count > 2 ? kept : points)
    }
}

// MARK: - Makers

extension Polygon {
    static func rectangle(_ rect: CGRect) -> Polygon {
        Polygon([
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY)
        ])
    }

    /// A regular polygon, and with enough sides, a stand-in for a circle.
    static func regular(sides: Int, radius: Double, center: CGPoint = .zero, rotation: Double = 0) -> Polygon {
        guard sides > 2 else { return Polygon([]) }
        let step = 2 * Double.pi / Double(sides)
        return Polygon((0..<sides).map { index in
            let angle = rotation + step * Double(index)
            return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        })
    }

    /// A star with `points` tips, for token levels and the app icon shape.
    static func star(points: Int, outerRadius: Double, innerRadius: Double, center: CGPoint = .zero) -> Polygon {
        guard points > 2 else { return Polygon([]) }
        let step = Double.pi / Double(points)
        return Polygon((0..<(points * 2)).map { index in
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = -Double.pi / 2 + step * Double(index)
            return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        })
    }
}
