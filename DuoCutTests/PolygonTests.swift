import CoreGraphics
import Foundation
import Testing

@testable import DuoCut

@Suite("Polygon")
struct PolygonTests {
    @Test func rectangleAreaAndCentroid() {
        let square = Polygon.rectangle(CGRect(x: 0, y: 0, width: 40, height: 20))
        #expect(abs(square.area - 800) < 1e-9)
        #expect(abs(square.centroid.x - 20) < 1e-9)
        #expect(abs(square.centroid.y - 10) < 1e-9)
        #expect(square.boundingBox == CGRect(x: 0, y: 0, width: 40, height: 20))
    }

    @Test func windingDoesNotChangeArea() {
        let square = Polygon.rectangle(CGRect(x: 0, y: 0, width: 10, height: 10))
        let reversed = Polygon(square.vertices.reversed())
        #expect(square.signedArea == -reversed.signedArea)
        #expect(square.area == reversed.area)
    }

    @Test func regularPolygonApproximatesACircle() {
        let circle = Polygon.regular(sides: 720, radius: 50)
        #expect(abs(circle.area - .pi * 2500) < 1)
    }

    @Test func transformsPreserveArea() {
        let star = Polygon.star(points: 5, outerRadius: 50, innerRadius: 20)
        let moved = star.translated(by: CGVector(dx: 17, dy: -3)).rotated(by: 0.7, around: CGPoint(x: 5, y: 5))
        #expect(abs(star.area - moved.area) < 1e-6)
        #expect(abs(star.scaled(by: 2, around: .zero).area - star.area * 4) < 1e-6)
    }

    @Test func containsPointsInsideOnly() {
        let square = Polygon.rectangle(CGRect(x: 0, y: 0, width: 10, height: 10))
        #expect(square.contains(CGPoint(x: 5, y: 5)))
        #expect(!square.contains(CGPoint(x: 15, y: 5)))
        #expect(!square.contains(CGPoint(x: -0.1, y: 5)))

        // The notch of an L is outside it, even though it's inside the bounding box.
        let ell = Polygon([
            CGPoint(x: 0, y: 0), CGPoint(x: 40, y: 0), CGPoint(x: 40, y: 20),
            CGPoint(x: 20, y: 20), CGPoint(x: 20, y: 60), CGPoint(x: 0, y: 60)
        ])
        #expect(ell.contains(CGPoint(x: 10, y: 50)))
        #expect(!ell.contains(CGPoint(x: 30, y: 50)))
    }

    @Test func simplifiedDropsDuplicatesAndStraightRuns() {
        let square = Polygon([
            CGPoint(x: 0, y: 0), CGPoint(x: 5, y: 0), CGPoint(x: 10, y: 0), CGPoint(x: 10, y: 0),
            CGPoint(x: 10, y: 10), CGPoint(x: 0, y: 10)
        ])
        let simplified = square.simplified()
        #expect(simplified.vertices.count == 4)
        #expect(abs(simplified.area - 100) < 1e-9)
    }

    @Test func lineSidesAndParameters() {
        let line = Line.vertical(x: 10)
        #expect(line.signedDistance(to: CGPoint(x: 10, y: 99)) == 0)
        #expect(line.signedDistance(to: CGPoint(x: 0, y: 0)) > 0)
        #expect(line.signedDistance(to: CGPoint(x: 20, y: 0)) < 0)
        #expect(abs(line.parameter(of: CGPoint(x: 10, y: 7)) - 7) < 1e-9)
        #expect(abs(line.point(at: 7).y - 7) < 1e-9)

        let turned = line.rotated(by: .pi / 2, around: CGPoint(x: 10, y: 0))
        #expect(abs(turned.signedDistance(to: CGPoint(x: 10, y: 5))) > 0)
        #expect(abs(turned.signedDistance(to: CGPoint(x: 99, y: 0))) < 1e-9)
    }
}
