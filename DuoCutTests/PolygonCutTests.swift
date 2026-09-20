import CoreGraphics
import Foundation
import Testing

@testable import DuoCut

@Suite("PolygonCut")
struct PolygonCutTests {
    /// An L: a 40×20 bar on top of a 20×40 column.
    private let ell = Polygon([
        CGPoint(x: 0, y: 0), CGPoint(x: 40, y: 0), CGPoint(x: 40, y: 20),
        CGPoint(x: 20, y: 20), CGPoint(x: 20, y: 60), CGPoint(x: 0, y: 60)
    ])

    /// A C opening to the right: a vertical line through the arms crosses it four times.
    private let cee = Polygon([
        CGPoint(x: 0, y: 0), CGPoint(x: 60, y: 0), CGPoint(x: 60, y: 20),
        CGPoint(x: 20, y: 20), CGPoint(x: 20, y: 60), CGPoint(x: 60, y: 60),
        CGPoint(x: 60, y: 80), CGPoint(x: 0, y: 80)
    ])

    @Test func squareInHalf() {
        let square = Polygon.rectangle(CGRect(x: 0, y: 0, width: 100, height: 60))
        let result = PolygonCut.split(square, by: .vertical(x: 50))
        #expect(result.isCut)
        #expect(result.positive.count == 1)
        #expect(result.negative.count == 1)
        let areas = result.areas()
        #expect(abs(areas.positive - 3000) < 1e-6)
        #expect(abs(areas.negative - 3000) < 1e-6)
    }

    @Test func squareOffCenter() {
        let square = Polygon.rectangle(CGRect(x: 0, y: 0, width: 100, height: 60))
        let result = PolygonCut.split(square, by: .vertical(x: 30))
        let areas = result.areas()
        // The positive side is the one the signed distance favors: x below the line.
        #expect(abs(areas.positive - 1800) < 1e-6)
        #expect(abs(areas.negative - 4200) < 1e-6)
    }

    @Test func squareOnTheDiagonal() {
        let square = Polygon.rectangle(CGRect(x: 0, y: 0, width: 100, height: 100))
        let diagonal = Line(point: .zero, direction: CGVector(dx: 1, dy: 1))
        let result = PolygonCut.split(square, by: diagonal)
        let areas = result.areas()
        #expect(abs(areas.positive - 5000) < 1e-6)
        #expect(abs(areas.negative - 5000) < 1e-6)
    }

    @Test func circleThroughTheCenter() {
        let circle = Polygon.regular(sides: 360, radius: 50, center: CGPoint(x: 100, y: 100))
        let result = PolygonCut.split(circle, by: .horizontal(y: 100))
        let areas = result.areas()
        #expect(abs(areas.positive - areas.negative) < 1e-6)
        #expect(abs(areas.positive + areas.negative - circle.area) < 1e-6)
    }

    @Test func concaveShapeKeepsItsAreas() {
        let result = PolygonCut.split(ell, by: .vertical(x: 30))
        #expect(result.positive.count == 1)
        #expect(result.negative.count == 1)
        let areas = result.areas()
        #expect(abs(areas.positive - 1400) < 1e-6)
        #expect(abs(areas.negative - 200) < 1e-6)
    }

    @Test func fourCrossingsMakeThreePieces() {
        let result = PolygonCut.split(cee, by: .vertical(x: 40))
        // The spine stays one piece; the two arm tips come off separately.
        #expect(result.positive.count == 1)
        #expect(result.negative.count == 2)
        let areas = result.areas()
        #expect(abs(areas.positive - 2400) < 1e-6)
        #expect(abs(areas.negative - 800) < 1e-6)
        #expect(abs(areas.positive + areas.negative - cee.area) < 1e-6)
    }

    @Test func lineThatMissesLeavesTheShapeWhole() {
        let square = Polygon.rectangle(CGRect(x: 0, y: 0, width: 10, height: 10))
        let result = PolygonCut.split(square, by: .vertical(x: 50))
        #expect(!result.isCut)
        #expect(result.positive.count == 1)
        #expect(result.negative.isEmpty)
        #expect(abs(result.areas().positive - 100) < 1e-6)
    }

    @Test func lineThroughASingleVertexDoesNotCut() {
        let triangle = Polygon([CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 20), CGPoint(x: -10, y: 20)])
        let result = PolygonCut.split(triangle, by: .horizontal(y: 0))
        #expect(!result.isCut)
        #expect(abs(result.areas().positive - triangle.area) < 1e-6)
    }

    @Test func lineAlongAnEdgeDoesNotCut() {
        let square = Polygon.rectangle(CGRect(x: 0, y: 0, width: 10, height: 10))
        let result = PolygonCut.split(square, by: .vertical(x: 0))
        #expect(!result.isCut)
        #expect(abs(result.areas().negative - 100) < 1e-6)
    }

    @Test func everyCutConservesArea() {
        let shapes = [
            ell,
            cee,
            Polygon.star(points: 5, outerRadius: 50, innerRadius: 18, center: CGPoint(x: 30, y: 30)),
            Polygon.regular(sides: 7, radius: 40, center: CGPoint(x: 10, y: -5))
        ]
        var generator = SystemRandomNumberGenerator()
        for shape in shapes {
            for _ in 0..<50 {
                let box = shape.boundingBox
                let point = CGPoint(
                    x: .random(in: box.minX...box.maxX, using: &generator),
                    y: .random(in: box.minY...box.maxY, using: &generator)
                )
                let angle = Double.random(in: 0..<(2 * .pi), using: &generator)
                let line = Line(point: point, direction: CGVector(dx: cos(angle), dy: sin(angle)))
                let areas = PolygonCut.split(shape, by: line).areas()
                #expect(abs(areas.positive + areas.negative - shape.area) < 1e-4)
            }
        }
    }
}
