import Foundation

/// Turns hinge angles into cuts.
///
/// A cut is a snap fold: the hinge closes by `threshold` degrees from its highest point.
/// After one, the detector waits until the device opens back up by `rearm` degrees, so a slow
/// close counts once. The same gesture works in both modes, and it's fast enough to use as
/// arcade timing — a sibling of DuoBird's flap, in the other direction.
struct CutDetector {
    /// How far the hinge must close, in degrees, to cut.
    var threshold = 12.0
    /// How far it must open again before the next cut.
    var rearm = 6.0

    /// What a finished snap looked like.
    struct Cut {
        /// Degrees per second at the moment of the cut. Fast snaps cut cleaner.
        var speed: Double
    }

    /// 0 to 1: how far into a snap the hinge is right now. Drives the blade's glow.
    private(set) var tension = 0.0

    private var isArmed = true
    private var highest: Double?
    private var lowest = 0.0
    private var lastDegrees: Double?
    private var lastTime: TimeInterval?

    /// Feeds the next hinge angle. Returns a cut when the snap completes.
    mutating func update(degrees: Double, at time: TimeInterval) -> Cut? {
        defer {
            lastDegrees = degrees
            lastTime = time
        }
        let speed = speed(to: degrees, at: time)

        if isArmed {
            let high = max(highest ?? degrees, degrees)
            highest = high
            tension = min(max((high - degrees) / threshold, 0), 1)
            if high - degrees >= threshold {
                isArmed = false
                lowest = degrees
                tension = 1
                return Cut(speed: speed)
            }
        } else {
            lowest = min(lowest, degrees)
            tension = 1
            if degrees - lowest >= rearm {
                isArmed = true
                highest = degrees
                tension = 0
            }
        }
        return nil
    }

    private func speed(to degrees: Double, at time: TimeInterval) -> Double {
        guard let lastDegrees, let lastTime, time > lastTime else { return 0 }
        return abs(degrees - lastDegrees) / (time - lastTime)
    }
}
