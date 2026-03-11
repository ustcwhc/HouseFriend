# CLAUDE.md

> Instructions for Claude Code when working on HouseFriend.

## Project Overview

HouseFriend is a Bay Area "Neighborhood Health Report" iOS app. It overlays 10 data layers (crime, noise, schools, etc.) on a map to help users evaluate neighborhoods before buying or renting.

## Tech Stack

- **iOS 17+**, SwiftUI + UIKit MapKit (`UIViewRepresentable` wrapping `MKMapView`)
- **Xcode 16** with `PBXFileSystemSynchronizedRootGroup` (new files auto-added to target)
- No package manager dependencies — all native frameworks

## Key Files

- `HouseFriend/Views/HFMapView.swift` — Core map component (UIViewRepresentable)
- `HouseFriend/Views/ContentView.swift` — Main view, all UI state
- `HouseFriend/Models/ZoomTier.swift` — Zoom tier enum + layer visibility rules
- `HouseFriend/Views/NoiseSmokeRenderer.swift` — Custom overlay renderer
- `HouseFriend/Views/CrimeTileOverlay.swift` — Crime heatmap tile overlay

## Coding Conventions

- **No large Swift literals**: Never embed datasets >1K lines as Swift arrays. Use bundled JSON.
- **Guard isFinite**: Always `guard value.isFinite` before `Int(someDouble)` conversions.
- **Zoom tier filtering**: All annotation visibility must go through `ZoomTier` enum thresholds.
- **Main thread = UI only**: All computation runs in `DispatchQueue.global` or `Task { }`.

## Workflow

- **Branching**: Meta-style stacked diffs on main. Create a PR for each change.
- **PR flow**: Create PR -> wait for review -> fix comments -> merge.
- **Direct commits**: Only when explicitly asked by the user.
- **Commit style**: Short, descriptive messages focused on "why" not "what".

## Reference Docs

- `README.md` — Product overview, features, status
- `ARCHITECTURE.md` — Technical architecture, file structure
- `DESIGN.md` — Design decisions and rationale
- `KNOWN_ISSUES.md` — Bug rules, lessons learned
- `ZOOM_VISIBILITY.md` — Per-layer zoom visibility reference

## Common Pitfalls

- `MKPolyline`/`MKPolygon` overlays must use UIKit renderer delegate, not SwiftUI overlay
- `.sheet(item:)` causes dismiss flicker — use `.sheet(isPresented:)` for seamless updates
- Xcode 16 auto-sync: don't manually add files to pbxproj, just place in the right directory
- Overpass API can timeout on Mac; works on iOS device
