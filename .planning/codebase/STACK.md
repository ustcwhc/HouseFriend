# Technology Stack

**Analysis Date:** 2026-03-21

## Languages

**Primary:**
- Swift 5.0 - All application source code (`HouseFriend/`)

**Secondary:**
- Python 3 - Data fetch scripts (`scripts/fetch_bayarea_roads.py`)

## Runtime

**Environment:**
- iOS 18.5+ (deployment target: `IPHONEOS_DEPLOYMENT_TARGET = 18.5`)
- Also builds for macOS 15.4+, visionOS 2.5+, and simulators
- Minimum functional target from CLAUDE.md: iOS 17+

**Build Tool:**
- Xcode 16.4 (`LastUpgradeCheck = 1640`)
- `PBXFileSystemSynchronizedRootGroup` — new files placed in the correct directory are auto-added to the target; do NOT manually edit `project.pbxproj`

## Frameworks

**Core UI:**
- SwiftUI — top-level app structure, all views except the map itself
- UIKit (via `UIViewRepresentable`) — `MKMapView` wrapped in `HouseFriend/Views/HFMapView.swift`

**Map & Location:**
- MapKit — `MKMapView`, `MKTileOverlay`, `MKPolyline`, `MKPolygon`, `MKAnnotationView`, `MKLocalSearchCompleter`, `MKLocalSearch`
- CoreLocation — `CLLocationManager` GPS in `HouseFriend/Services/LocationService.swift`

**Data & Networking:**
- Foundation — `URLSession`, `JSONDecoder`, `JSONSerialization`
- Combine — used in `SearchCompleterService.swift`
- Compression — gzip decompression of `bayarea_roads.json.gz` in `HouseFriend/Services/NoiseService.swift`

**Logging:**
- os.Logger — centralized via `HouseFriend/Services/AppLogger.swift`; subsystem `com.housefriend`, categories: `network`, `scoring`, `location`, `map`

**Testing:**
- XCTest — unit tests in `HouseFriendTests/HouseFriendTests.swift`
- XCUITest — UI tests in `HouseFriendUITests/`

## Key Dependencies

**No third-party package dependencies.** The `packageProductDependencies` array in `project.pbxproj` is empty. All functionality is built on Apple system frameworks.

## Bundled Data Assets

**Critical:**
- `HouseFriend/bayarea_roads.json.gz` — 514 KB gzip; 15K road/railway segments for the noise layer (static tier, loads on init)
- `HouseFriend/bayarea_zips.json` — 693 KB; 445 ZIP polygons from Census TIGER 2023

These files are loaded at runtime via `Bundle.main.url(forResource:withExtension:)`. They must remain in the `HouseFriend/` source directory.

## Configuration

**Build:**
- Bundle identifier: `Wancoco.HouseFriend`
- Swift version: 5.0
- Optimization: `-Onone` (Debug), default (Release)
- Entitlements: `HouseFriend/HouseFriend.entitlements` (empty dict — no special entitlements)
- Location usage string: "HouseFriend uses your location to analyze neighborhood safety, air quality, earthquake risk, and more."

**Environment:**
- No `.env` files — no API keys required (all external APIs used are keyless)
- No SPM packages, no CocoaPods, no Carthage

## Platform Requirements

**Development:**
- macOS with Xcode 16.4+
- Apple Developer account (team `T539CYBWJW`) for device builds

**Production:**
- iOS App Store distribution
- Supported orientations: Portrait + Landscape (both iPhone and iPad)
- Targeted device families: iPhone (1), iPad (2), Vision (7)

---

*Stack analysis: 2026-03-21*
