# Architecture

> Technical architecture and implementation details for HouseFriend.

---

## Tech Stack

| Component | Technology | Notes |
|-----------|-----------|-------|
| Framework | SwiftUI + UIKit MapKit (iOS 17+) | UIViewRepresentable wrapping MKMapView |
| Map overlays | MKTileOverlay / MKPolyline / MKPolygon | Native MapKit, follows map dragging |
| Crime heatmap | `CrimeTileOverlay: MKTileOverlay` | Background CGContext rendering, 64x64 tiles |
| Noise roads | Bundled `bayarea_roads.json.gz` (514 KB) + OSM Overpass API | Two-tier: static instant + dynamic detail |
| Air quality | Open-Meteo API (free, no key) | Returns real us_aqi |
| Earthquake | USGS Earthquake API | M>=2.5, real-time |
| Schools | Hardcoded 130+ schools by county | Static data |
| ZIP boundaries | `bayarea_zips.json` (693 KB) | Census TIGER 2023, 445 ZIPs |
| Address search | `MKLocalSearchCompleter` + `MKLocalSearch` | Fuzzy autocomplete, Bay Area biased |
| Location | `CLLocationManager` | GPS auto-locate |
| Build | Xcode 16, `PBXFileSystemSynchronizedRootGroup` | New files auto-added to target |

---

## File Structure

```
HouseFriend/
├── bayarea_zips.json               # 445 ZIP polygons (Census TIGER 2023, 693 KB)
├── bayarea_roads.json.gz           # 15K road/railway segments (514 KB gzip)
├── GeoJSONParser.swift             # GeoJSON parsing utility
├── Models/
│   ├── NeighborhoodCategory.swift  # CategoryType enum, NeighborhoodCategory
│   ├── CrimeMarker.swift           # CrimeMarker, CrimeType
│   ├── MapZone.swift               # MapZone (polygon + value)
│   ├── ZIPCodeData.swift           # ZIPCodeRegion, ZIPDemographics, runtime JSON loading
│   └── ZoomTier.swift              # ZoomTier enum + LayerVisibility per-layer rules
├── Services/
│   ├── AirQualityService.swift     # Open-Meteo API
│   ├── CrimeService.swift          # SF Open Data + mock
│   ├── EarthquakeService.swift     # USGS API
│   ├── ElectricLinesService.swift  # Hardcoded PG&E corridors
│   ├── FireDataService.swift       # Hardcoded CAL FIRE 22 zones
│   ├── LocationService.swift       # CLLocationManager
│   ├── NoiseService.swift          # Bundled roads + Overpass API, two-tier loading
│   ├── PopulationService.swift     # Hardcoded 65-city population density
│   ├── SchoolService.swift         # Hardcoded 130+ schools
│   ├── SearchCompleterService.swift
│   ├── SuperfundService.swift      # Hardcoded 62 sites
│   └── SupportiveHousingService.swift
├── Views/
│   ├── ContentView.swift           # Main view (map + all layers + ZIP UX)
│   ├── CategoryCardView.swift      # Bottom score cards
│   ├── CrimeTileOverlay.swift      # MKTileOverlay, background CGContext rendering
│   ├── CrimeMarkerView.swift       # Details mode annotations
│   ├── DetailSheetView.swift       # School/Superfund/Housing detail sheet
│   ├── HFMapView.swift             # UIViewRepresentable MKMapView (core)
│   ├── LegendView.swift            # Legend
│   ├── NoiseSmokeRenderer.swift    # Custom MKOverlayRenderer, 4-layer smoke effect
│   └── ZIPDemographicsSheet.swift  # ZIP demographics panel
├── scripts/
│   └── fetch_bayarea_roads.py      # Overpass API fetch script for bundled road data
└── Assets.xcassets/
```

---

## Key Architecture Decisions

### SwiftUI Map -> UIKit MKMapView

SwiftUI's native `Map` view caused two critical problems:
1. `MapPolyline` causes O(n) view rebuilds — hundreds of roads freeze the UI
2. `overlay()` uses screen-space coordinates — overlays don't follow map dragging

Solution: `UIViewRepresentable` wrapping `MKMapView`. All overlays are in MapKit coordinate space, perfectly following the map.

### Two-Tier Noise Loading

1. **Static bundle** (`bayarea_roads.json.gz`, 514 KB): 15K major road/railway segments, loaded on init, renders instantly at City zoom
2. **Dynamic Overpass API**: Secondary/residential streets, fetched on demand at Neighborhood zoom

This gives instant response on layer switch while adding detail when zoomed in.

### Zoom Tier Visibility System

Five canonical zoom tiers control what renders at each zoom level. See [ZOOM_VISIBILITY.md](ZOOM_VISIBILITY.md) for the full reference.

```
Satellite ─── 5.0° ─── State ─── 1.2° ─── County ─── 0.3° ─── City ─── 0.08° ─── Neighborhood
```

Implementation: `ZoomTier.swift` enum + `LayerVisibility` nested enums. Filtering happens in `HFMapView.updateAnnotations()` on `regionDidChangeAnimated`.

---

## Core Components

### HFMapView.swift (UIViewRepresentable)

The central map component. Key responsibilities:
- Manages MKMapView lifecycle and delegate callbacks
- Routes tap/long-press gestures to SwiftUI callbacks
- Filters annotations by zoom tier on region change
- Manages overlay renderers (crime tiles, noise smoke, ZIP polygons, fire/electric/AQ)
- ZIP polygon hit testing via ray-casting point-in-polygon

Key callbacks:
```swift
var onZIPTap:           (ZIPCodeRegion) -> Void
var onMapTap:           (CLLocationCoordinate2D) -> Void
var onMapLongPress:     (CLLocationCoordinate2D) -> Void
var onNoiseFetchCancel: () -> Void
```

### ContentView.swift (Main View)

Orchestrates all UI state:
```swift
@State var mapRegion: MKCoordinateRegion
@State var selectedCategory: CategoryType = .population
@State var highlightedZIPId: String?
@State var selectedZIP: ZIPCodeRegion?
@State var showZIPSheet = false
@State var pinnedLocation: CLLocationCoordinate2D?
```

### CrimeTileOverlay.swift

Custom `MKTileOverlay` that renders 64x64 pixel heatmap tiles using Gaussian decay model. `crimeValue(lat:lon:) -> Double` is the shared API used by both tile rendering and score computation.

### NoiseSmokeRenderer.swift

Custom `MKOverlayRenderer` with 4-layer smoke effect:
1. Outer haze (12x width, 0.025 alpha)
2. Mid haze (6x width, 0.06 alpha)
3. Inner smoke (3x width, 0.12 alpha)
4. Core line (1x width, 0.75 alpha)

Railways get dashed core lines.

---

## Data Flow

### Layer Loading

```
App launch -> Population layer loaded (JSON parse, ~0.1s)
User switches layer -> loadLayerIfNeeded() -> async fetch/parse
Already-loaded layers skip (isLoaded flag)
```

### Per-Layer Loading Strategy

| Layer | Network | Cache Strategy |
|-------|---------|---------------|
| Crime | No (pure computation) | Permanent tile cache (MapKit auto) |
| Noise | Yes (Overpass, detail only) | Static bundle instant + refresh on zoom |
| Schools | No | Permanent (hardcoded) |
| Earthquake | Yes (USGS) | 30-minute TTL |
| Fire / Electric / Housing | No | Permanent (hardcoded) |
| Air Quality | Yes (Open-Meteo) | 1-hour TTL |
| Population | No (JSON bundle) | Permanent |

---

## Performance Requirements

| Operation | Requirement |
|-----------|-------------|
| Map pan / zoom | 60fps, no dropped frames |
| Layer switch | < 16ms response, async data loading |
| Bottom panel pop-up | < 200ms |
| Search autocomplete | < 150ms after input |
| ZIP area tap | < 50ms response |

Guidelines:
1. Main thread is UI-only — all computation in `DispatchQueue.global` or `Task { }`
2. Max 200 MapPolygons on screen at once
3. Use stable `id:` to prevent SwiftUI view rebuilds
4. Network request debouncing: 0.5s for Overpass
5. Hash-based change detection for noise overlay updates
