import Testing

@Suite("Smoke")
struct SmokeTests {
    @Test func testTargetRuns() {
        #expect(Bool(true))
    }
}
