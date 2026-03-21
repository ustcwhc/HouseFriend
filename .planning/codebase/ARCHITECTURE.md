# Architecture

**Analysis Date:** 2026-03-21

## Pattern Overview

**Overall:** Single-screen SwiftUI app with a UIKit bridge for map rendering, following an observable services pattern for data management.

**Key Characteristics:**
- `ContentView` owns all app state via `@State` and `@StateObject`; there is no separate view model layer
- All 11 data services are `ObservableObject` classes instantiated directly in `ContentView` as `@StateObject`
- `HFMapView` is a `UIViewRepresentable` wrapping `MKMapView`, used because SwiftUI's `Map` cannot host `MKTileOverlay` or custom `MKOverlayRenderer` renderers
- No third-party dependencies; entirely native Apple frameworks (SwiftUI, UIKit, MapKit, CoreLocation, os)

## Layers

**Entry / Composition Layer:**
- Purpose: Root UI, wires all services to the map and UI panels
- Location: `HouseFriend/ContentView.swift`
- Contains: All `@State`/`@StateObject` declarations, `body` with `ZStack` layout, private helpers (`loadLayerIfNeeded`, `computeScores`, `refreshCrimeIncidents`)
- Depends on: All services, models, `HFMapView`, all panel views
- Used by: `HouseFriendApp` as the root `WindowGroup` scene

**Map Bridge Layer:**
- Purpose: UIKit MKMapView hosting, overlay/annotation lifecycle, gesture handling
- Location: `HouseFriend/Views/HFMapView.swift`
- Contains: `HFMapView` (`UIViewRepresentable`), `Coordinator` (implements `MKMapViewDelegate`, `UIGestureRecognizerDelegate`), `HFAnnotation` class, `HFAnnotationData` enum
- Depends on: `ZoomTier`, all layer-specific model types, `NoiseSmokeRenderer`, `CrimeTileOverlay`
- Used by: `ContentView`

**Services Layer:**
- Purpose: Data fetching, caching, and publishing via `@Published` properties
- Location: `HouseFriend/Services/`
- Contains: One `ObservableObject` class per layer (11 services total)
- Depends on: Foundation, MapKit, CoreLocation; each service may call external APIs or load from bundle
- Used by: `ContentView` (all services as `@StateObject`)

**Models Layer:**
- Purpose: Value types representing domain entities passed between services and views
- Location: `HouseFriend/Models/` plus inline structs within service files (e.g., `NoiseRoad`, `NoiseZone` in `NoiseService.swift`)
- Contains: `ZoomTier`, `NeighborhoodCategory`, `CrimeMarker`, `MapZone`, `ZIPCodeData`, `ZIPCodeRegion`, `ZIPDemographics`
- Depends on: Foundation, MapKit, CoreLocation, SwiftUI
- Used by: Services, views, `HFMapView`

**Scoring Layer:**
- Purpose: Pure computation of 0–100 scores and labels per data layer for a given coordinate
- Location: `HouseFriend/Services/ScoringService.swift`
- Contains: `enum ScoringService` (namespace for static methods), `ScoreResult` struct; one static function per layer
- Depends on: Foundation, MapKit, model types
- Used by: `ContentView.computeScores(coord:)`

**Rendering / Custom Overlay Layer:**
- Purpose: Custom UIKit drawing for overlay types MapKit cannot style via simple properties
- Location: `HouseFriend/Views/NoiseSmokeRenderer.swift`, `HouseFriend/Views/CrimeTileOverlay.swift`
- Contains: `NoiseSmokeRenderer: MKOverlayRenderer` (multi-layer smoke effect for noise polylines), `CrimeTileOverlay: MKTileOverlay` (Gaussian heatmap tiles rendered on background thread)
- Depends on: MapKit, UIKit
- Used by: `HFMapView.Coordinator.mapView(_:rendererFor:)`

**Panel / Sheet Views Layer:**
- Purpose: Secondary UI surfaces for detail information and categorical score cards
- Location: `HouseFriend/Views/` (excluding `HFMapView.swift`)
- Contains: `CategoryCardView`, `CrimeMarkerView`, `DetailSheetView` (schools, superfund, housing sheets), `LegendView`, `ZIPDemographicsSheet`
- Depends on: SwiftUI, model types
- Used by: `ContentView` via `.sheet(item:)` and inline in `bottomPanel`/`ZStack`

## Data Flow

**Layer Selection and Data Load:**

1. User taps layer button in `ContentView.sideBar`
2. `selectedCategory` state updates
3. `loadLayerIfNeeded(_:)` fires the relevant service's `fetch()` if data is empty
4. Service sets `isLoading = true`, issues network or bundle read on background thread
5. Service publishes results on main thread via `@Published` properties
6. `ContentView` re-renders, passing new data arrays into `HFMapView` as value-type props
7. `HFMapView.updateUIView` calls `Coordinator.updateOverlays` and `Coordinator.updateAnnotations`

**Neighborhood Report (Long Press):**

1. User long-presses map; `HFMapView.Coordinator.handleLongPress` fires
2. `onMapLongPress` callback delivers `CLLocationCoordinate2D` to `ContentView`
3. `pinnedLocation` state is set; `computeScores(coord:)` is called
4. `computeScores` calls `ScoringService` static methods with current service data
5. `categories` array is updated with scores; `bottomPanel` renders score cards
6. Reverse geocode runs via `CLGeocoder`; `pinnedAddress` updates when complete

**Camera Change:**

1. User pans/zooms; `Coordinator.mapView(_:regionDidChangeAnimated:)` fires
2. `onCameraChange` callback updates `currentCenter`, `currentSpan`, `mapRegion` in `ContentView`
3. If noise layer is active, `NoiseService.fetchForRegion(_:)` is called with new viewport
4. `ZoomTier` recomputed; if tier changed, `updateAnnotations` is called to show/hide items

**Annotation Visibility (Zoom-Based Diffing):**

1. On each zoom tier change, `Coordinator.updateAnnotations` builds `wanted: [String: HFAnnotation]` keyed by stable string IDs
2. Diff against `annotationMap` (current annotations): compute `toRemove` and `toAdd` sets
3. Only changed annotations are added/removed from `MKMapView`, preventing full re-render flicker

**State Management:**
- All state lives in `ContentView` as `@State`/`@StateObject` — no external store
- Services publish data changes; `ContentView` passes data down as let-properties to `HFMapView`
- Callbacks (closures) flow user interactions back up from `HFMapView` to `ContentView`

## Key Abstractions

**ZoomTier:**
- Purpose: Canonical 5-level zoom enum that gates what is rendered at each scale
- Location: `HouseFriend/Models/ZoomTier.swift`
- Pattern: `enum ZoomTier: Int, Comparable` with convenience booleans (`showsCrimeMarkers`, `showsCityAnnotations`, etc.) and `schoolLevelsToShow() -> Set<SchoolLevel>`. `LayerVisibility` nested enums document minimum tiers per object type.

**HFAnnotation / HFAnnotationData:**
- Purpose: Stable UIKit annotation wrapper with typed payload; keyed by a string ID to enable efficient diffing
- Location: `HouseFriend/Views/HFMapView.swift` (bottom of file)
- Pattern: `class HFAnnotation: NSObject, MKAnnotation` holds `HFAnnotationData` enum with associated values for each layer type

**ScoringService:**
- Purpose: Stateless computation layer; all scoring logic extracted from `ContentView` into testable static functions
- Location: `HouseFriend/Services/ScoringService.swift`
- Pattern: `enum ScoringService` used as a namespace; each `static func` takes service data + coordinate and returns `ScoreResult(score: Int, label: String)`

**ObservableObject Services:**
- Purpose: Per-layer data container that fetches, holds, and publishes layer data
- Location: `HouseFriend/Services/*.swift`
- Pattern: `class XService: ObservableObject` with `@Published var [entities]`, `@Published var isLoading`, `@Published var errorMessage`, and a public `fetch()` or `fetchNear(lat:lon:)` entry point. Background work on `DispatchQueue.global` or `URLSession`; main-thread publish via `DispatchQueue.main.async`.

## Entry Points

**App Launch:**
- Location: `HouseFriend/HouseFriendApp.swift`
- Triggers: iOS app lifecycle `@main`
- Responsibilities: Creates `WindowGroup { ContentView() }`; no DI container or setup

**ContentView.onAppear:**
- Location: `HouseFriend/ContentView.swift` (`.onAppear` modifier, line ~200)
- Triggers: First render of `ContentView`
- Responsibilities: Calls `locationService.requestPermission()` and `loadLayerIfNeeded(.population)` to pre-load the default layer

**HFMapView.makeUIView:**
- Location: `HouseFriend/Views/HFMapView.swift`
- Triggers: SwiftUI creates the `UIViewRepresentable`
- Responsibilities: Instantiates `MKMapView`, assigns delegate to `Coordinator`, adds tap and long-press gesture recognizers, sets initial region

## Error Handling

**Strategy:** Services set `errorMessage: String?` on failure; `ContentView` aggregates via a computed `activeServiceError` property and shows a timed auto-dismissing banner.

**Patterns:**
- Network failures fall back to mock/estimated data (e.g., `CrimeService.loadMockData`)
- `guard value.isFinite` before any `Double` → geometry conversion (enforced in `ScoringService`)
- `AppLogger` subsystem loggers (`network`, `scoring`, `location`, `map`) used for structured `os.Logger` output

## Cross-Cutting Concerns

**Logging:** `AppLogger` enum in `HouseFriend/Services/AppLogger.swift` — four category loggers backed by `os.Logger`. Use `AppLogger.network.error(...)` etc.

**Validation:** `guard value.isFinite` pattern before integer casts from `Double`; array bounds guarded via custom `Array[safe: index]` subscript in `HFMapView.swift`.

**Authentication:** None — all data is either bundled, public API (no key), or mock.

**Threading:** All service fetches run on `DispatchQueue.global(qos: .userInitiated)` or `URLSession` background threads; main-thread updates via `DispatchQueue.main.async`. `CrimeTileOverlay.loadTile` runs on `DispatchQueue.global(qos: .userInitiated)`.

---

*Architecture analysis: 2026-03-21*
