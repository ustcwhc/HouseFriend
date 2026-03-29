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

## Channel Reply Rule (MANDATORY)

When a message originates from an external channel (Discord `<channel source="discord" ...>`, Telegram, or any MCP-bridged chat), you MUST reply exclusively through that channel's reply tool (e.g., `mcp__plugin_discord_discord__reply`). **Never** output plain text to the CLI as your response — the channel user cannot see CLI output and will be left waiting with no reply. This applies to all responses: answers, follow-up questions, status updates, errors, and confirmations. If you need to run tools (read files, edit code, run commands), do so silently, then send the final response through the channel.

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

<!-- GSD:project-start source:PROJECT.md -->
## Project

**HouseFriend**

HouseFriend is a Bay Area "Neighborhood Health Report" iOS app that overlays 10 data layers (crime, noise, schools, earthquake, fire, electric lines, supportive housing, air quality, superfund, population) on a map to help users evaluate neighborhoods before buying or renting. It targets all 9 Bay Area counties with 445 ZIP code boundaries, long-press neighborhood scoring, and address search.

**Core Value:** Users can instantly visualize and score any Bay Area neighborhood across 10 safety/quality dimensions from a single map interface — no tables, no switching apps, just tap and see.

### Constraints

- **Tech stack**: Native iOS only (SwiftUI + UIKit), no third-party dependencies — maintaining zero-dependency approach
- **Platform**: iOS 17+ minimum, built with Xcode 16.4
- **Performance**: Must maintain 60fps — all computation on background threads, UI thread for rendering only
- **Data**: All external APIs must be keyless or use free tiers — no paid API subscriptions for v1
- **Thread safety**: guard value.isFinite before all Double→Int conversions; MKPolyline/MKPolygon via UIKit renderer delegate only
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- Swift 5.0 - All application source code (`HouseFriend/`)
- Python 3 - Data fetch scripts (`scripts/fetch_bayarea_roads.py`)
## Runtime
- iOS 18.5+ (deployment target: `IPHONEOS_DEPLOYMENT_TARGET = 18.5`)
- Also builds for macOS 15.4+, visionOS 2.5+, and simulators
- Minimum functional target from CLAUDE.md: iOS 17+
- Xcode 16.4 (`LastUpgradeCheck = 1640`)
- `PBXFileSystemSynchronizedRootGroup` — new files placed in the correct directory are auto-added to the target; do NOT manually edit `project.pbxproj`
## Frameworks
- SwiftUI — top-level app structure, all views except the map itself
- UIKit (via `UIViewRepresentable`) — `MKMapView` wrapped in `HouseFriend/Views/HFMapView.swift`
- MapKit — `MKMapView`, `MKTileOverlay`, `MKPolyline`, `MKPolygon`, `MKAnnotationView`, `MKLocalSearchCompleter`, `MKLocalSearch`
- CoreLocation — `CLLocationManager` GPS in `HouseFriend/Services/LocationService.swift`
- Foundation — `URLSession`, `JSONDecoder`, `JSONSerialization`
- Combine — used in `SearchCompleterService.swift`
- Compression — gzip decompression of `bayarea_roads.json.gz` in `HouseFriend/Services/NoiseService.swift`
- os.Logger — centralized via `HouseFriend/Services/AppLogger.swift`; subsystem `com.housefriend`, categories: `network`, `scoring`, `location`, `map`
- XCTest — unit tests in `HouseFriendTests/HouseFriendTests.swift`
- XCUITest — UI tests in `HouseFriendUITests/`
## Key Dependencies
## Bundled Data Assets
- `HouseFriend/bayarea_roads.json.gz` — 514 KB gzip; 15K road/railway segments for the noise layer (static tier, loads on init)
- `HouseFriend/bayarea_zips.json` — 693 KB; 445 ZIP polygons from Census TIGER 2023
## Configuration
- Bundle identifier: `Wancoco.HouseFriend`
- Swift version: 5.0
- Optimization: `-Onone` (Debug), default (Release)
- Entitlements: `HouseFriend/HouseFriend.entitlements` (empty dict — no special entitlements)
- Location usage string: "HouseFriend uses your location to analyze neighborhood safety, air quality, earthquake risk, and more."
- No `.env` files — no API keys required (all external APIs used are keyless)
- No SPM packages, no CocoaPods, no Carthage
## Platform Requirements
- macOS with Xcode 16.4+
- Apple Developer account (team `T539CYBWJW`) for device builds
- iOS App Store distribution
- Supported orientations: Portrait + Landscape (both iPhone and iPad)
- Targeted device families: iPhone (1), iPad (2), Vision (7)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- PascalCase for all Swift files: `HFMapView.swift`, `ZoomTier.swift`, `CrimeService.swift`
- Views suffix: `DetailSheetView.swift`, `CategoryCardView.swift`, `LegendView.swift`
- Service suffix: `CrimeService.swift`, `NoiseService.swift`, `SchoolService.swift`
- Renderer suffix: `NoiseSmokeRenderer.swift`, `CrimeTileOverlay.swift`
- PascalCase: `EarthquakeEvent`, `ZoomTier`, `HFAnnotation`, `NoiseRoad`
- `HF` prefix for UIKit-bridging types only: `HFMapView`, `HFAnnotation`, `HFAnnotationData`
- Codable inner types are nested inside the owning service: `EarthquakeService.USGSResponse`, `EarthquakeService.Feature`
- camelCase: `fetchForRegion`, `updateOverlays`, `applyZipStyle`, `loadStaticRoads`
- Boolean properties use declarative names: `showsNoiseRoads`, `showsCrimeMarkers`, `isLoading`, `isRailway`
- Factory/static methods use noun phrases: `allBayAreaSchools()`, `parseBundledJSON(_:)`, `parseOSMResponse(_:)`
- camelCase throughout: `noiseRoads`, `zipRenderers`, `annotationMap`, `lastZoomTier`
- Short single-letter locals only in tight loops: `i`, `j`, `n`, `t`
- Constants use descriptive camelCase: `maxSpanForDetail`, `maxSpanForMajor`
- camelCase: `.satellite`, `.neighborhood`, `.fireHazard`, `.milpitasOdor`
- Associated values use the model type name directly: `.school(School)`, `.earthquake(EarthquakeEvent)`
## Code Style
- No automated formatter config (no `.swiftlint.yml`, no Biome, no Prettier)
- Indentation: 4 spaces
- Opening braces on same line
- Aligned assignment columns used for visual grouping in dense initializers and switch bodies:
- No SwiftLint or external linter detected
- Code quality enforced via CLAUDE.md rules and code review
## Import Organization
## Error Handling
## Logging
## Comments
- MARK sections are used consistently to divide all files into named regions: `// MARK: - Overlay management`
- Inline comments explain non-obvious decisions (algorithm rationale, bug fixes tagged with ID, UIKit gotchas):
- Doc comments (`///`) on public-facing types and non-trivial computed properties:
- Avoid restating the code — prefer explaining "why"
## Concurrency
- Network callbacks use `URLSession.shared.dataTask` with `defer { DispatchQueue.main.async { self?.isLoading = false } }` pattern
- `[weak self]` is used in all closures that capture service objects
- `Task {}` is preferred for new async/await code; `DispatchQueue.global` for existing patterns
## Function Design
## Module Design
## Zoom Tier Filtering
## Data Embedding
- `bayarea_zips.json` loaded by `ZIPCodeData.allZIPs()`
- `bayarea_roads.json.gz` loaded by `NoiseService.loadStaticRoads()`
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- `ContentView` owns all app state via `@State` and `@StateObject`; there is no separate view model layer
- All 11 data services are `ObservableObject` classes instantiated directly in `ContentView` as `@StateObject`
- `HFMapView` is a `UIViewRepresentable` wrapping `MKMapView`, used because SwiftUI's `Map` cannot host `MKTileOverlay` or custom `MKOverlayRenderer` renderers
- No third-party dependencies; entirely native Apple frameworks (SwiftUI, UIKit, MapKit, CoreLocation, os)
## Layers
- Purpose: Root UI, wires all services to the map and UI panels
- Location: `HouseFriend/ContentView.swift`
- Contains: All `@State`/`@StateObject` declarations, `body` with `ZStack` layout, private helpers (`loadLayerIfNeeded`, `computeScores`, `refreshCrimeIncidents`)
- Depends on: All services, models, `HFMapView`, all panel views
- Used by: `HouseFriendApp` as the root `WindowGroup` scene
- Purpose: UIKit MKMapView hosting, overlay/annotation lifecycle, gesture handling
- Location: `HouseFriend/Views/HFMapView.swift`
- Contains: `HFMapView` (`UIViewRepresentable`), `Coordinator` (implements `MKMapViewDelegate`, `UIGestureRecognizerDelegate`), `HFAnnotation` class, `HFAnnotationData` enum
- Depends on: `ZoomTier`, all layer-specific model types, `NoiseSmokeRenderer`, `CrimeTileOverlay`
- Used by: `ContentView`
- Purpose: Data fetching, caching, and publishing via `@Published` properties
- Location: `HouseFriend/Services/`
- Contains: One `ObservableObject` class per layer (11 services total)
- Depends on: Foundation, MapKit, CoreLocation; each service may call external APIs or load from bundle
- Used by: `ContentView` (all services as `@StateObject`)
- Purpose: Value types representing domain entities passed between services and views
- Location: `HouseFriend/Models/` plus inline structs within service files (e.g., `NoiseRoad`, `NoiseZone` in `NoiseService.swift`)
- Contains: `ZoomTier`, `NeighborhoodCategory`, `CrimeMarker`, `MapZone`, `ZIPCodeData`, `ZIPCodeRegion`, `ZIPDemographics`
- Depends on: Foundation, MapKit, CoreLocation, SwiftUI
- Used by: Services, views, `HFMapView`
- Purpose: Pure computation of 0–100 scores and labels per data layer for a given coordinate
- Location: `HouseFriend/Services/ScoringService.swift`
- Contains: `enum ScoringService` (namespace for static methods), `ScoreResult` struct; one static function per layer
- Depends on: Foundation, MapKit, model types
- Used by: `ContentView.computeScores(coord:)`
- Purpose: Custom UIKit drawing for overlay types MapKit cannot style via simple properties
- Location: `HouseFriend/Views/NoiseSmokeRenderer.swift`, `HouseFriend/Views/CrimeTileOverlay.swift`
- Contains: `NoiseSmokeRenderer: MKOverlayRenderer` (multi-layer smoke effect for noise polylines), `CrimeTileOverlay: MKTileOverlay` (Gaussian heatmap tiles rendered on background thread)
- Depends on: MapKit, UIKit
- Used by: `HFMapView.Coordinator.mapView(_:rendererFor:)`
- Purpose: Secondary UI surfaces for detail information and categorical score cards
- Location: `HouseFriend/Views/` (excluding `HFMapView.swift`)
- Contains: `CategoryCardView`, `CrimeMarkerView`, `DetailSheetView` (schools, superfund, housing sheets), `LegendView`, `ZIPDemographicsSheet`
- Depends on: SwiftUI, model types
- Used by: `ContentView` via `.sheet(item:)` and inline in `bottomPanel`/`ZStack`
## Data Flow
- All state lives in `ContentView` as `@State`/`@StateObject` — no external store
- Services publish data changes; `ContentView` passes data down as let-properties to `HFMapView`
- Callbacks (closures) flow user interactions back up from `HFMapView` to `ContentView`
## Key Abstractions
- Purpose: Canonical 5-level zoom enum that gates what is rendered at each scale
- Location: `HouseFriend/Models/ZoomTier.swift`
- Pattern: `enum ZoomTier: Int, Comparable` with convenience booleans (`showsCrimeMarkers`, `showsCityAnnotations`, etc.) and `schoolLevelsToShow() -> Set<SchoolLevel>`. `LayerVisibility` nested enums document minimum tiers per object type.
- Purpose: Stable UIKit annotation wrapper with typed payload; keyed by a string ID to enable efficient diffing
- Location: `HouseFriend/Views/HFMapView.swift` (bottom of file)
- Pattern: `class HFAnnotation: NSObject, MKAnnotation` holds `HFAnnotationData` enum with associated values for each layer type
- Purpose: Stateless computation layer; all scoring logic extracted from `ContentView` into testable static functions
- Location: `HouseFriend/Services/ScoringService.swift`
- Pattern: `enum ScoringService` used as a namespace; each `static func` takes service data + coordinate and returns `ScoreResult(score: Int, label: String)`
- Purpose: Per-layer data container that fetches, holds, and publishes layer data
- Location: `HouseFriend/Services/*.swift`
- Pattern: `class XService: ObservableObject` with `@Published var [entities]`, `@Published var isLoading`, `@Published var errorMessage`, and a public `fetch()` or `fetchNear(lat:lon:)` entry point. Background work on `DispatchQueue.global` or `URLSession`; main-thread publish via `DispatchQueue.main.async`.
## Entry Points
- Location: `HouseFriend/HouseFriendApp.swift`
- Triggers: iOS app lifecycle `@main`
- Responsibilities: Creates `WindowGroup { ContentView() }`; no DI container or setup
- Location: `HouseFriend/ContentView.swift` (`.onAppear` modifier, line ~200)
- Triggers: First render of `ContentView`
- Responsibilities: Calls `locationService.requestPermission()` and `loadLayerIfNeeded(.population)` to pre-load the default layer
- Location: `HouseFriend/Views/HFMapView.swift`
- Triggers: SwiftUI creates the `UIViewRepresentable`
- Responsibilities: Instantiates `MKMapView`, assigns delegate to `Coordinator`, adds tap and long-press gesture recognizers, sets initial region
## Error Handling
- Network failures fall back to mock/estimated data (e.g., `CrimeService.loadMockData`)
- `guard value.isFinite` before any `Double` → geometry conversion (enforced in `ScoringService`)
- `AppLogger` subsystem loggers (`network`, `scoring`, `location`, `map`) used for structured `os.Logger` output
## Cross-Cutting Concerns
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
