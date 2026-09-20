import CoreGraphics
import Foundation

/// Splits polygons with a straight line — the whole point of the game.
///
/// The line is infinite, so a cut always separates the shape into everything on the
/// positive side of the line and everything on the negative one. Concave shapes can fall
/// apart into several pieces per side, which is why each side is an array.
///
/// How it works: every vertex gets a signed distance to the line, intersection points are
/// spliced into the ring where the sign flips, and the ring breaks into chains that stay on
/// one side. Chains are then stitched back together along the cut line — a chain's end joins
/// the nearest chain start, which is what keeps a C-shaped piece one piece instead of two.
nonisolated enum PolygonCut {
    struct Result: Equatable {
        /// Pieces on the side the line's signed distance is positive.
        var positive: [Polygon]
        /// Pieces on the other side.
        var negative: [Polygon]

        var isCut: Bool { !positive.isEmpty && !negative.isEmpty }

        func areas() -> (positive: Double, negative: Double) {
            (positive.reduce(0) { $0 + $1.area }, negative.reduce(0) { $0 + $1.area })
        }
    }

    /// Cuts `polygon` with `line`. Vertices closer to the line than `tolerance` count as on it.
    static func split(_ polygon: Polygon, by line: Line, tolerance: Double = 1e-7) -> Result {
        let vertices = polygon.vertices
        guard vertices.count > 2 else { return Result(positive: [], negative: []) }

        let distances = vertices.map { distance -> Double in
            let value = line.signedDistance(to: distance)
            return abs(value) < tolerance ? 0 : value
        }
        guard distances.contains(where: { $0 > 0 }), distances.contains(where: { $0 < 0 }) else {
            // The line misses the shape, or only touches it: one side keeps everything.
            let piece = polygon.simplified()
            return distances.contains(where: { $0 > 0 })
                ? Result(positive: [piece], negative: [])
                : Result(positive: [], negative: [piece])
        }

        let ring = augmentedRing(vertices: vertices, distances: distances)
        return Result(
            positive: pieces(in: ring, side: 1, line: line),
            negative: pieces(in: ring, side: -1, line: line)
        )
    }

    /// A vertex of the ring, tagged with the side of the line it sits on.
    private struct Node {
        var point: CGPoint
        /// 1, -1, or 0 when the node is on the line.
        var side: Int
    }

    /// The polygon's vertices with intersection points spliced in wherever an edge crosses the line.
    private static func augmentedRing(vertices: [CGPoint], distances: [Double]) -> [Node] {
        var ring: [Node] = []
        for index in vertices.indices {
            let next = (index + 1) % vertices.count
            let current = distances[index]
            let following = distances[next]
            ring.append(Node(point: vertices[index], side: current == 0 ? 0 : (current > 0 ? 1 : -1)))
            if current * following < 0 {
                let ratio = current / (current - following)
                let start = vertices[index]
                let end = vertices[next]
                let crossing = CGPoint(x: start.x + (end.x - start.x) * ratio, y: start.y + (end.y - start.y) * ratio)
                ring.append(Node(point: crossing, side: 0))
            }
        }
        return ring
    }

    /// Chains of the ring that stay on one side, each running from one point on the line to the next.
    private static func chains(in ring: [Node], side: Int) -> [[CGPoint]] {
        guard let start = ring.firstIndex(where: { $0.side == 0 }) else { return [] }
        var chains: [[CGPoint]] = []
        var current: [CGPoint] = [ring[start].point]
        var holdsSide = false
        for step in 1...ring.count {
            let node = ring[(start + step) % ring.count]
            current.append(node.point)
            if node.side * side > 0 { holdsSide = true }
            if node.side == 0 {
                if holdsSide { chains.append(current) }
                current = [node.point]
                holdsSide = false
            }
        }
        return chains
    }

    /// Stitches the chains back into closed pieces.
    ///
    /// Where the line runs through the shape it leaves spans: sorted along the line, the
    /// crossings pair up as first-with-second, third-with-fourth, and so on, and every span is
    /// inside the shape. A chain that ends at one end of a span continues at the chain starting
    /// at its other end — that's what keeps the spine of a C one piece while its arm tips come
    /// off separately.
    private static func pieces(in ring: [Node], side: Int, line: Line) -> [Polygon] {
        let chains = chains(in: ring, side: side)
        guard !chains.isEmpty else { return [] }

        struct Endpoint {
            var parameter: Double
            var chain: Int
            var isStart: Bool
        }
        var endpoints: [Endpoint] = []
        for (index, chain) in chains.enumerated() {
            endpoints.append(Endpoint(parameter: line.parameter(of: chain[0]), chain: index, isStart: true))
            endpoints.append(Endpoint(parameter: line.parameter(of: chain[chain.count - 1]), chain: index, isStart: false))
        }
        endpoints.sort { $0.parameter < $1.parameter }

        // Chain that continues after the one that ends at this span.
        var continuation: [Int: Int] = [:]
        for index in stride(from: 0, to: endpoints.count - 1, by: 2) {
            let (one, other) = (endpoints[index], endpoints[index + 1])
            if !one.isStart, other.isStart { continuation[one.chain] = other.chain }
            if !other.isStart, one.isStart { continuation[other.chain] = one.chain }
        }

        var remaining = Set(chains.indices)
        var pieces: [Polygon] = []
        while let first = remaining.min() {
            var points: [CGPoint] = []
            var index = first
            while remaining.contains(index) {
                remaining.remove(index)
                points.append(contentsOf: chains[index])
                guard let next = continuation[index], next != first else { break }
                index = next
            }
            let piece = Polygon(points).simplified()
            if piece.area > 1e-6 { pieces.append(piece) }
        }
        return pieces
    }
}
