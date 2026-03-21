# Codebase Structure

**Analysis Date:** 2026-03-21

## Directory Layout

```
HouseFriend/                         # Xcode project root
├── HouseFriend/                     # App source (PBXFileSystemSynchronizedRootGroup)
│   ├── HouseFriendApp.swift         # @main entry point
│   ├── ContentView.swift            # Root view + all app state
│   ├── GeoJSONParser.swift          # Utility: GeoJSON polygon parsing
│   ├── Models/                      # Value types and domain enums
│   │   ├── ZoomTier.swift           # Zoom tier enum + per-layer visibility rules
│   │   ├── NeighborhoodCategory.swift  # CategoryType enum + NeighborhoodCategory data
│   │   ├── CrimeMarker.swift        # CrimeType enum + CrimeMarker struct
│   │   ├── MapZone.swift            # Generic MapZone (polygon + value)
│   │   └── ZIPCodeData.swift        # ZIPCodeRegion, ZIPDemographics + bundle loader
│   ├── Services/                    # ObservableObject data providers
│   │   ├── AppLogger.swift          # os.Logger subsystem wrappers
│   │   ├── AirQualityService.swift  # Air quality / Milpitas odor layer
│   │   ├── CrimeService.swift       # Crime incidents + stats (SF Open Data API)
│   │   ├── EarthquakeService.swift  # USGS earthquake feed
│   │   ├── ElectricLinesService.swift # High-voltage transmission lines
│   │   ├── FireDataService.swift    # CAL FIRE hazard zones
│   │   ├── LocationService.swift    # CoreLocation wrapper (CLLocationManager)
│   │   ├── NoiseService.swift       # Noise roads (bundled JSON + Overpass API)
│   │   ├── PopulationService.swift  # Population / density data
│   │   ├── SchoolService.swift      # Bay Area schools (hardcoded dataset)
│   │   ├── ScoringService.swift     # Pure scoring computation (static methods)
│   │   ├── SearchCompleterService.swift # MKLocalSearchCompleter wrapper
│   │   └── SuperfundService.swift   # EPA Superfund sites
│   ├── Views/                       # SwiftUI views + UIKit bridge components
│   │   ├── HFMapView.swift          # UIViewRepresentable wrapping MKMapView
│   │   ├── NoiseSmokeRenderer.swift # MKOverlayRenderer for noise polylines
│   │   ├── CrimeTileOverlay.swift   # MKTileOverlay for crime heatmap
│   │   ├── CrimeMarkerView.swift    # SwiftUI crime marker icon
│   │   ├── CategoryCardView.swift   # Score card for bottom panel
│   │   ├── DetailSheetView.swift    # Modal sheets: School, Superfund, Housing
│   │   ├── LegendView.swift         # Per-layer map legend
│   │   └── ZIPDemographicsSheet.swift # ZIP code demographics bottom drawer
│   └── bayarea_zips.json            # Bundled ZIP polygon + demographics data
├── HouseFriend.xcodeproj/           # Xcode project file (auto-sync enabled)
├── HouseFriendTests/                # Unit test target
│   └── HouseFriendTests.swift       # ScoringService unit tests (Swift Testing)
├── HouseFriendUITests/              # UI test target
│   ├── HouseFriendUITests.swift
│   └── HouseFriendUITestsLaunchTests.swift
├── scripts/                         # Build/data scripts (non-Swift)
├── .planning/                       # GSD planning documents
│   └── codebase/                    # Codebase analysis documents
└── CLAUDE.md                        # AI assistant instructions
```

## Directory Purposes

**`HouseFriend/Models/`:**
- Purpose: Shared value types and domain enums used across services and views
- Contains: Structs, enums, bundle-loading helpers
- Key files: `ZoomTier.swift` (visibility rules), `NeighborhoodCategory.swift` (all 10 layer definitions), `ZIPCodeData.swift` (bundle loader + demographics struct)
- Note: Some model types are defined inline within their service file (e.g., `NoiseRoad`, `NoiseZone` in `NoiseService.swift`; `CrimeIncident`, `CrimeStats` in `CrimeService.swift`)

**`HouseFriend/Services/`:**
- Purpose: One `ObservableObject` per data layer, fetching and publishing data
- Contains: `class XService: ObservableObject` with `@Published` properties; `ScoringService` (pure static methods); `AppLogger` (logging); `SearchCompleterService` (address search)
- Key files: `ScoringService.swift` (testable scoring logic), `NoiseService.swift` (hybrid static + Overpass API)

**`HouseFriend/Views/`:**
- Purpose: All visual components — both SwiftUI views and UIKit bridge objects
- Contains: SwiftUI `View` structs, `UIViewRepresentable` bridge, `MKOverlayRenderer` subclass, `MKTileOverlay` subclass
- Key files: `HFMapView.swift` (core map), `NoiseSmokeRenderer.swift` (custom drawing), `CrimeTileOverlay.swift` (heatmap tiles)

**`HouseFriendTests/`:**
- Purpose: Unit tests for pure-logic components (currently `ScoringService`)
- Framework: Swift Testing (`@Test`, `#expect`)
- Not an XCTest target — uses the newer Swift Testing framework

## Key File Locations

**Entry Points:**
- `HouseFriend/HouseFriendApp.swift`: `@main` struct, creates `ContentView`
- `HouseFriend/ContentView.swift`: Root view owning all state; ~900 lines

**Configuration:**
- `HouseFriend/HouseFriendApp.swift`: No configuration; app ID and capabilities in `HouseFriend.xcodeproj`

**Core Logic:**
- `HouseFriend/Views/HFMapView.swift`: Map rendering, overlay lifecycle, annotation diffing
- `HouseFriend/Models/ZoomTier.swift`: Canonical zoom thresholds and all layer visibility rules
- `HouseFriend/Services/ScoringService.swift`: All neighborhood scoring algorithms

**Bundled Data:**
- `HouseFriend/bayarea_zips.json`: ZIP code polygon boundaries + demographics (~445 ZIPs)
- `bayarea_roads.json` (referenced in `NoiseService.swift` as `Bundle.main.url(forResource: "bayarea_roads", withExtension: "json")`) — provides static major road geometries for the noise layer

**Testing:**
- `HouseFriendTests/HouseFriendTests.swift`: All current unit tests (scoring + geometry)

## Naming Conventions

**Files:**
- Services: `{Domain}Service.swift` (e.g., `CrimeService.swift`, `SchoolService.swift`)
- Views: descriptive PascalCase matching their primary type (e.g., `CategoryCardView.swift`, `DetailSheetView.swift`)
- Models: named after the primary type they define (e.g., `ZoomTier.swift`, `CrimeMarker.swift`)
- Renderers/Overlays: named by their rendering purpose (e.g., `NoiseSmokeRenderer.swift`, `CrimeTileOverlay.swift`)

**Directories:**
- PascalCase: `Models/`, `Services/`, `Views/`

**Types:**
- Services: `class {Domain}Service: ObservableObject`
- Models: `struct {Name}` or `enum {Name}` (value types)
- Map data: `class {Purpose}Overlay: MKTileOverlay`, `final class {Purpose}Renderer: MKOverlayRenderer`
- Annotations: `class HFAnnotation: NSObject, MKAnnotation` (must be reference type for MapKit)

**Properties:**
- Published service properties use plural names for collections: `@Published var schools: [School]`, `@Published var lines: [ElectricLine]`
- Published single-value: `@Published var isLoading: Bool`, `@Published var errorMessage: String?`

## Where to Add New Code

**New Data Layer (e.g., "Transit"):**
1. Create model: `HouseFriend/Models/TransitStop.swift`
2. Create service: `HouseFriend/Services/TransitService.swift` — `class TransitService: ObservableObject`
3. Add `case transit` to `CategoryType` in `HouseFriend/Models/NeighborhoodCategory.swift`
4. Add entry to `NeighborhoodCategory.all` array in the same file
5. Add zoom visibility rules to `LayerVisibility` in `HouseFriend/Models/ZoomTier.swift`
6. Add scoring function to `HouseFriend/Services/ScoringService.swift`
7. Wire `@StateObject private var transitService = TransitService()` in `ContentView`
8. Pass data into `HFMapView` and handle in `Coordinator.updateAnnotations` or `updateOverlays`

**New SwiftUI View (panel, sheet, card):**
- Implementation: `HouseFriend/Views/{Name}View.swift` or `{Name}Sheet.swift`

**New Model Type:**
- Standalone: `HouseFriend/Models/{TypeName}.swift`
- Tightly coupled to a service: define inline in the service file (consistent with `NoiseRoad`, `CrimeIncident`)

**Scoring Logic:**
- Add a static function to `HouseFriend/Services/ScoringService.swift` following the `(data, coord) -> ScoreResult` signature pattern

**Unit Tests:**
- Add `@Test func ...` functions to `HouseFriendTests/HouseFriendTests.swift`

## Special Directories

**`.planning/`:**
- Purpose: GSD planning and codebase analysis documents
- Generated: No — manually maintained
- Committed: Yes

**`scripts/`:**
- Purpose: Data preparation and build helper scripts
- Generated: No
- Committed: Yes

**`HouseFriend.xcodeproj/`:**
- Purpose: Xcode project definition; uses `PBXFileSystemSynchronizedRootGroup` — new files placed in the correct directory are automatically included in the build target without manually editing `project.pbxproj`
- Generated: Partially (user data excluded via `.gitignore`)
- Committed: Yes (project file only; xcuserdata excluded)

---

*Structure analysis: 2026-03-21*
