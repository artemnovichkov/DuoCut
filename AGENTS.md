# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Project

DuoCut is a SwiftUI game for the iPhone Duo (iOS 27.1). The cut line never moves — it lives on the
hinge — so the player drags and rotates the shape under a fixed blade and snaps the hinge to cut.
Two modes: Puzzle (authored levels, precision) and Arcade (flying fruit, timing).

`docs/ROADMAP.md` is the source of truth for progress. Check items off as they land, and start a new
session at the first unchecked item.

## Commands

The Xcode project uses the JSON project format: `DuoCut.xcodeproj/project.xcproj` (there is no
`project.pbxproj`). Files are listed explicitly under `"files"`, grouped by folder. When you add,
remove, or rename a source file, edit its entry by hand, for example:

```json
{ "path": "Polygon.swift", "target-membership": [ "DuoCut/compile-sources" ] },
```

Test files use `"DuoCutTests/compile-sources"`, asset catalogs `"DuoCut/resources"`.

```bash
xcodebuild -project DuoCut.xcodeproj -scheme DuoCut \
  -destination 'platform=iOS Simulator,name=iPhone Duo' build
xcodebuild test -project DuoCut.xcodeproj -scheme DuoCut \
  -destination 'platform=iOS Simulator,name=iPhone Duo'
xcrun simctl launch booted com.artemnovichkov.DuoCut
```

Tests cover pure geometry only (`Geometry/`); everything else is verified by hand on the simulator.

The iPhone Duo simulator has two displays. `xcrun simctl io booted screenshot` captures the inner
display; add `--display=1` for the outer one. Only the active display has content. Use the `hinge`
skill in `.agents/skills/hinge` to fold, half-open, or unfold the simulator and to read the angle.

## Architecture

- `Geometry/` — pure, UI-free math: `Polygon` (shoelace area, centroid, transforms) and
  `PolygonCut` (splitting a polygon by a line, concave shapes included). Under test.
- `Fold/` — `FoldLine` derives the cut line from `reservedRegions(kind: .division,
  options: [.includeInactive])` inside a `GeometryReader`; regions arrive after the first layout
  pass, so read them in the body and never cache them. `CutDetector` turns `onHingeChange` angles
  into a snap-cut (a quick 10–15° fold), like DuoBird's `FlapDetector`.
- `Play/` — shared pieces and physics for the halves that fly apart, stepped in
  `TimelineView(.animation)`. No SpriteKit; `Canvas` draws everything.
- `Puzzle/`, `Arcade/`, `Meta/` — the two modes and the meta layer (achievements, fold counter,
  daily challenge, share card).

Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Custom `Shape` types must be declared
`nonisolated struct`, or the `Shape` conformance fails to compile.

## Style

- Minimal visuals: paper background, ink lines, one accent (see `Palette` in `App/RootView.swift`).
- A swipe across the cut line cuts too, so the game still works on a phone without a hinge.
