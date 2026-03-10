# HouseFriend — Master Plan

> **One-liner:** A Bay Area "Neighborhood Health Report" — overlay 10 layers of real data on a map to help users see the full picture of safety, environment, schools, and noise before buying or renting.
>
> Comparable product: App Store "Neighborhood Check" (id6446656055)
>
> **Latest commit:** `6278fa7` | GitHub: ustcwhc/HouseFriend | Last updated: 2026-03-09

---

## Table of Contents
1. [Product Vision](#1-product-vision)
2. [10 Data Layers](#2-10-data-layers)
3. [Feature Spec](#3-feature-spec)
4. [Completed Features](#4-completed-features)
5. [Pending Features](#5-pending-features)
6. [Technical Architecture](#6-technical-architecture)
7. [Zoom-Level Visibility Rules](#7-zoom-level-visibility-rules)
8. [Performance Requirements](#8-performance-requirements)
9. [File Structure](#9-file-structure)
10. [Data Coverage](#10-data-coverage)
11. [Known Issues & Rules](#11-known-issues--rules)

---

## 1. Product Vision

### Core User Scenarios
- A user looking to buy/rent in the Bay Area opens the app → searches an address → instantly sees the neighborhood's comprehensive safety score
- A parent concerned about schools switches to the school layer to view nearby school ratings
- A user sensitive to noise/air quality switches to the corresponding layer for an intuitive overview

### Design Principles
- **Map-first**: All data is overlaid on the map with colors, no tables
- **One-tap rating**: Long-press an address to pop up a "Neighborhood Report" at the bottom with A/B/C/D/F ratings
- **Full coverage**: Data covers all 9 counties of the San Francisco Bay Area, not just Silicon Valley
- **Lazy loading**: Data for a layer is only loaded when the user switches to it
- **Silky smooth**: No jank in any operation, maintain 60fps at all times

---

## 2. 10 Data Layers

| # | Layer | Rendering | Data Source | Coverage |
|---|-------|-----------|-------------|----------|
| 1 | Crime | `CrimeTileOverlay` (MKTileOverlay, background CGContext rendering) | Gaussian model | Full Bay Area |
| 2 | Noise | `MKPolyline` (UIKit, <=200 roads) | OSM Overpass API real-time | Real-time dynamic |
| 3 | Schools | `MKAnnotation` pins | Hardcoded 130+ schools | All 9 Bay Area counties |
| 4 | Superfund | `MKAnnotation` pins | Hardcoded 62 sites | Full Bay Area |
| 5 | Earthquake | `MKCircle` scaled by magnitude | USGS real-time API | Real-time |
| 6 | Fire Hazard | `MKPolygon` | Hardcoded 22 CAL FIRE zones | Full Bay Area |
| 7 | Electric Lines | `MKPolyline` | Hardcoded PG&E transmission corridors | Main lines only |
| 8 | Supportive Housing | `MKAnnotation` pins | Hardcoded | Limited coverage |
| 9 | Air Quality/Odor | `MKPolygon` | Open-Meteo API + hardcoded industrial zones | Full Bay Area |
| 10 | Population | `MKPolygon` ZIP polygons + demographics sheet | Census TIGER 2023 JSON | 445 ZIPs |

---

## 3. Feature Spec

### 3.1 Complete User Journey

```
Open app
  |
See Bay Area ZIP map (Population layer default, 445 ZIPs with yellow borders)
GPS locates and map auto-flies to current position
  |
Tap a ZIP area (anywhere inside)
  |
Map centers on that ZIP (visible area center), demographics panel pops up at bottom
Tap another ZIP -> panel seamlessly switches (no dismiss)
  |
Switch to Crime layer
  |
ZIP panel auto-closes; map shows crime heatmap
  |
Long-press a GPS point on the map (0.45s)
  |
Pin drops, bottom expands with Neighborhood Report (scores for each layer)
  |
Switch to Schools layer
  |
Neighborhood Report auto-closes; map shows school pins
Tap a school pin -> detail sheet pops up
  |
Search "1234 Main St, Sunnyvale"
  |
Map flies to Sunnyvale, pin drops, bottom expands with Neighborhood Report
View comprehensive scores, swipe through layer score cards
```

### 3.2 Population Layer (Core Feature)

**Visual Design**
- 445 Census TIGER ZIP areas, gold border (0.88, 0.72, 0.0), 70% opacity, line width 1.5
- Unselected: transparent fill, border only
- Selected (highlighted): pink fill (systemPink 28%) + pink border (85%)

**Tap Interaction**
- **Tap anywhere inside a ZIP area** -> ray-casting detection -> highlight + bottom ZIPDemographicsSheet pops up
- **Tap another ZIP while sheet is open** -> seamless switch (sheet content updates, no dismiss)
- **Switch layers while sheet is open** -> sheet auto-closes (0.3s animation then clears)
- **Long-press anywhere on map** -> open GPS coordinate Neighborhood Report (works on any layer)

**ZIP Map Centering Rules**
```
Sheet height = 52% of screen
Visible map height = 48%
Visible area center = 24% from top (= full screen center 50% - 26%)
-> mapRegion.center.latitude = zip.center.latitude - latSpan * 0.26
```

**ZIPDemographicsSheet Contains:**
1. Racial distribution (horizontal stacked color bar)
2. Household income distribution (vertical bar chart)
3. Age distribution (horizontal bar chart)

Data source: 2020 Census, `ZIPDemographics` struct fields (all Int):
`population, medianIncome, white, hispanic, asian, black, other`
`incUnder50, inc50_100, inc100_150, inc150_200, inc200Plus`
`age_under18, age_18_34, age_35_54, age_55_74, age_75Plus`
(`medianAge: Double` is the only Double field)

### 3.3 Address Search

- Autocomplete suggestions appear after the 1st character typed (`MKLocalSearchCompleter`)
- Dropdown list has two tiers: fuzzy autocomplete (instant) + full results (with coordinates)
- Tap any suggestion -> map flies to that address (span ~ 0.03 deg)
- Red pin appears on the map, bottom panel expands with Neighborhood Report
- Bay Area results are prioritized

### 3.4 Crime Layer

**MKTileOverlay Rendering Spec**
- Background thread computes a 64x64 pixel heatmap for each Web Mercator tile (z/x/y)
- `CrimeTileOverlay.crimeValue(lat:lon:) -> Double` is the standard API (called by both ContentView and tile renderer)
- Gaussian model: each hotspot uses `exp(-distMiles^2 / radius^2)`, radius 2-5mi

**Color Spec**
| Value | Color |
|-------|-------|
| >0.72 | Dark red (191,13,13) |
| 0.55-0.72 | Orange-red (235,64,20) |
| 0.40-0.55 | Orange (250,133,38) |
| 0.28-0.40 | Amber (254,184,89) |
| 0.18-0.28 | Light amber (255,219,153) |
| <0.18 | Beige (255,238,200) |

### 3.5 Noise Layer

- Each road is an `MKPolyline`, colored by type, max 200 roads
- Highway (motorway): purple 5px; residential street: green 2px
- `cancelFetch()` cancels old Overpass request when map pans

### 3.6 Neighborhood Report Bottom Panel

**Trigger: Long-press on map** (0.45s) -> pin drops -> bottom panel expands

**Auto-closes when switching layers** (`onChange(of: selectedCategory)` clears `pinnedLocation`)

**Score Computation Notes**
- All `Double -> Int` conversions must first `guard value.isFinite` (R010)
- `electricLines` branch: give 75 score + "Data loading..." when no data
- `fireHazard` branch: `minDist` can be infinity, use `safeMinDist`

### 3.7 Loading Strategy

**Lazy Loading**
- On app launch, only Population is loaded (JSON parsing, ~0.1s)
- Other layers are loaded on switch via `loadLayerIfNeeded()`
- Already-loaded layers have an `isLoaded: Bool` flag to prevent duplicate requests

**Per-Layer Loading Strategy**

| Layer | Network | Cache Strategy |
|-------|---------|---------------|
| Crime | No (pure computation) | Permanent tile cache (MapKit auto) |
| Noise | Yes (Overpass) | Refresh when viewport moves >50% |
| Schools | No | Permanent (hardcoded) |
| Earthquake | Yes (USGS) | 30-minute TTL |
| Fire / Electric / Housing | No | Permanent (hardcoded) |
| Air Quality | Yes (Open-Meteo) | 1-hour TTL |
| Population | No (JSON bundle) | Permanent |

---

## 4. Completed Features

### UI
- [x] Right-side vertical sidebar (10 layer toggle buttons, ScrollView to prevent clipping)
- [x] Top address search bar (`MKLocalSearchCompleter` fuzzy autocomplete)
- [x] Bottom Neighborhood Report panel (expands after **long-press**)
- [x] Score cards (progress ring + A/B/C/D/F letter rating)
- [x] Legend displayed in bottom-left corner
- [x] Zoom +/- buttons (bottom-right)
- [x] Current location button
- [x] Active layer label (chip at top of map)

### Map Layers
- [x] Crime: MKTileOverlay pixel heatmap (smooth gradient, follows map dragging)
- [x] Noise: Overpass API dynamically fetches each road, colored by road type; cancelFetch on pan
- [x] Schools: 130+ schools, tap to show detail sheet
- [x] Superfund: 62 sites, tap to show details
- [x] Earthquake: USGS real-time, circle size = magnitude
- [x] Fire Hazard: 22 CAL FIRE zones
- [x] Electric Lines, Supportive Housing, Air Quality
- [x] Population: 445 Census TIGER ZIPs, yellow borders, tap -> pink highlight + demographics sheet

### Population Layer UX
- [x] Tap **anywhere inside** a ZIP area to open ZIP info (ray-casting point-in-polygon detection)
- [x] While ZIP info panel is open, tap another ZIP -> seamless content switch, **no dismiss-and-reopen**
- [x] Long-press anywhere on map -> open GPS coordinate Neighborhood Report (works on any layer)
- [x] Switching layers auto-closes ZIP panel (0.3s animation then clears selectedZIP)
- [x] Switching layers auto-closes Neighborhood Report panel (clears pinnedLocation + scores)
- [x] After ZIP selection, map flies to center on the **visible area center after sheet pop-up** (south offset = latSpan x 0.26)

### Data
- [x] Full 9-county Bay Area coverage (Santa Clara, Alameda, SF, San Mateo, Contra Costa, Marin, Sonoma, Napa, Solano)
- [x] 445 Bay Area ZIP polygons (Census TIGER 2023, RDP simplified to ~80 points/ZIP)
- [x] Default layer: Population (ZIP map visible on app launch)
- [x] Default view: center (37.450, -122.050), span 0.06 deg (neighborhood level), auto-flies to GPS location

### Bug Fixes (This Sprint)
- [x] `Int(Double.infinity)` crash in `computeScores()` electricLines case
- [x] Defensive fixes for remaining branches in the same function (noise zone, fire minDist)

---

## 5. Pending Features

### High Priority
- [ ] **Noise Layer UI**: Show spinner while loading, fallback to hardcoded data when Overpass fails
- [ ] **Loading Animation**: Show spinner overlay when switching layers (spec written in 3.7)
- [ ] **Supportive Housing Expansion**: Add SF, Oakland, Berkeley, San Mateo supportive housing data

### Medium Priority
- [ ] **Crime Details Real Data**: Integrate SF Open Data, Oakland Crime API to replace mock data
- [ ] **School Rating Data**: Integrate GreatSchools API or CA School Dashboard data
- [ ] **Electric Lines Expansion**: Add sub-115kV distribution lines
- [ ] **Neighborhood Report Enhancement**: Add descriptive text for each layer (not just scores)

### Low Priority
- [ ] Dark mode support
- [ ] iPad layout optimization
- [ ] Share feature (screenshot + score card image generation)
- [ ] Saved/favorited addresses

---

## 6. Technical Architecture

| Layer | Technology | Notes |
|-------|-----------|-------|
| Framework | SwiftUI + UIKit MapKit (iOS 17+) | UIViewRepresentable wrapping MKMapView |
| Map overlays | MKTileOverlay / MKPolyline / MKPolygon | All native MapKit, follows map dragging |
| Crime heatmap | `CrimeTileOverlay: MKTileOverlay` | Background thread CGContext rendering 64x64 tiles |
| Road network data | OpenStreetMap Overpass API (real-time) | Noise layer, no API Key needed |
| Air quality | Open-Meteo API (free, no Key) | Returns real us_aqi |
| Earthquake data | USGS Earthquake API | M>=2.5, real-time |
| School data | Hardcoded 130+ schools, organized by county | Includes ratings and types |
| ZIP boundaries | `bayarea_zips.json` (693KB bundled resource) | Census TIGER 2023, 445 Bay Area ZIPs |
| Address search | `MKLocalSearchCompleter` + `MKLocalSearch` | Fuzzy autocomplete, biased toward Bay Area |
| Location | `CLLocationManager` | Current location -> auto-analyze |
| Build | Xcode 16, `PBXFileSystemSynchronizedRootGroup` | New files auto-added to target |

### Key Architecture Decision: SwiftUI Map -> UIKit MKMapView

**Reasons:**
- SwiftUI `MapPolyline` causes O(n) view rebuilds; hundreds of roads freeze the UI
- SwiftUI `overlay()` uses screen-space coordinates; overlays don't follow map dragging
- `UIViewRepresentable` wrapping `MKMapView`: all overlays are in MapKit coordinate space, perfectly following the map

**Key Files:**
- `HouseFriend/Views/HFMapView.swift` — `UIViewRepresentable` wrapping `MKMapView`
  - `onMapTap` callback (non-Population layers, tap = no-op)
  - `onMapLongPress` callback (long press -> GPS neighborhood report)
  - `onZIPTap` callback (Population layer, tap = ZIP info)
  - `onNoiseFetchCancel` callback (cancel Overpass request on pan)
  - `highlightedZIPId: String?` -> highlights selected ZIP polygon
  - `zipRenderers: [String: MKPolygonRenderer]` -> renderer cache
  - `coordinateInsidePolygon()` -> ray-casting point-in-polygon detection
- `HouseFriend/Views/CrimeTileOverlay.swift` — `MKTileOverlay`
  - `static crimeValue(lat:lon:) -> Double` standard method
  - Background thread rendering, MapKit auto-caches tiles

### ZIP Data Architecture

**Data source:** OpenDataDE/State-zip-code-GeoJSON (Census TIGER 2023)
- CA raw file 71MB -> filtered to Bay Area -> 445 ZIPs
- Stored at: `HouseFriend/bayarea_zips.json` (693KB, auto-included by PBXFileSystemSynchronizedRootGroup)
- **NEVER** embed 445 ZIPs as Swift literals — SourceKitService will OOM crash

**Loading:** `ZIPCodeData.swift` (65 lines) parses JSON at runtime, RDP simplification (<=80 points/ZIP, epsilon=0.0006 deg)

---

## 7. Zoom-Level Visibility Rules

All rendered objects have a visibility threshold tied to the map's zoom level (span in degrees). When zoomed out beyond an object's threshold, it is not rendered — saving computation and reducing visual clutter.

### Zoom Tiers

| Tier | Approx. Span | What's Visible on Map | Rendered Objects |
|------|-------------|----------------------|-----------------|
| **T0 — Country** | > 5° | State outlines | Nothing — all layers disabled |
| **T1 — Region** | 1.2° – 5° | Counties, major cities | Nothing — too zoomed out for any meaningful data |
| **T2 — Metro** | 0.3° – 1.2° | Freeways visible | ZIP-level overlays (Population polygons), high schools, fire hazard zones, electric transmission lines |
| **T3 — City** | 0.08° – 0.3° | Boulevards / arterials visible | Middle schools, Superfund sites, earthquake markers, crime heatmap tiles, noise (major roads + railways only, static bundled data) |
| **T4 — Neighborhood** | < 0.08° | Residential streets visible | Elementary schools, individual crime markers (clickable), supportive housing pins, noise (all streets via Overpass detail fetch), air quality zones |

### Per-Layer Visibility Mapping

| Layer | T0–T1 | T2 (Freeway) | T3 (Boulevard) | T4 (Street) |
|-------|-------|-------------|----------------|-------------|
| Population (ZIP polygons) | Hidden | **Visible** | Visible | Visible |
| Crime (heatmap tiles) | Hidden | Hidden | **Visible** | Visible |
| Crime (individual markers) | Hidden | Hidden | Hidden | **Visible + clickable** |
| Noise (major roads/railways) | Hidden | Hidden | **Visible** (static bundle) | Visible |
| Noise (secondary/residential) | Hidden | Hidden | Hidden | **Visible** (Overpass fetch) |
| Schools (high school) | Hidden | **Visible** | Visible | Visible |
| Schools (middle school) | Hidden | Hidden | **Visible** | Visible |
| Schools (elementary) | Hidden | Hidden | Hidden | **Visible** |
| Earthquake | Hidden | Hidden | **Visible** | Visible |
| Fire Hazard | Hidden | **Visible** | Visible | Visible |
| Electric Lines | Hidden | **Visible** | Visible | Visible |
| Superfund | Hidden | Hidden | **Visible** | Visible |
| Supportive Housing | Hidden | Hidden | Hidden | **Visible** |
| Air Quality / Odor | Hidden | Hidden | Hidden | **Visible** |

### Implementation Notes

- **Span thresholds**: Use `region.span.latitudeDelta` to determine current tier. Thresholds: T1→T2 at 1.2°, T2→T3 at 0.3°, T3→T4 at 0.08°.
- **Noise layer already implements this**: `maxSpanForMajor = 1.2` (nothing rendered above), `maxSpanForDetail = 0.08` (Overpass detail below).
- **Annotation layers**: Filter annotations in `updateAnnotations()` based on zoom tier — e.g., only show `school.level == .high` when span > 0.08°.
- **Crime markers**: Only show individual `CrimeMarker` annotations when span < 0.08° (T4). Heatmap tiles render at T3+.
- **Performance benefit**: At T2 with 445 ZIP polygons already on screen, hiding school/superfund/housing pins avoids hundreds of unnecessary annotation views.

---

## 8. Performance Requirements

### Red Lines (Non-negotiable)

| Operation | Requirement |
|-----------|-------------|
| Map pan / zoom | Always 60fps, no dropped frames |
| Layer switch animation | < 16ms response, data loading is async and never blocks UI |
| Bottom panel pop-up | < 200ms, smooth animation |
| Search autocomplete suggestions | Appear < 150ms after input |
| Map fly-to animation | Smooth animation, no dropped frames |
| Crime heatmap rendering | Background thread computation, main thread only draws |
| ZIP area tap highlight | Instant response (< 50ms) |

### Implementation Guidelines

1. **Main thread is UI-only**: All data computation must run in `DispatchQueue.global` or `Task { }`
2. **MapPolygon count control**: No more than 200 MapPolygons on the map at any time
3. **Avoid ForEach rebuilds**: Use stable `id:` identifiers to prevent unnecessary SwiftUI view rebuilds
4. **Image / render caching**: CGImage heatmap only redraws when region changes by more than 20%
5. **Network request debouncing**: Overpass and similar network requests have 0.5s debounce to avoid frequent triggers during dragging

---

## 9. File Structure

```
HouseFriend/
├── bayarea_zips.json               # 445 Bay Area ZIP polygons (Census TIGER 2023, 693KB)
├── GeoJSONParser.swift                # GeoJSON parsing utility
├── Models/
│   ├── NeighborhoodCategory.swift     # CategoryType enum, NeighborhoodCategory
│   ├── CrimeMarker.swift              # CrimeMarker, CrimeType
│   ├── MapZone.swift                  # MapZone (polygon + value)
│   └── ZIPCodeData.swift              # ZIPCodeRegion, ZIPDemographics, runtime JSON loading (65 lines)
├── Services/
│   ├── AirQualityService.swift     # Open-Meteo API
│   ├── CrimeService.swift          # SF Open Data + mock
│   ├── EarthquakeService.swift     # USGS API
│   ├── ElectricLinesService.swift  # Hardcoded PG&E corridors
│   ├── FireDataService.swift       # Hardcoded CAL FIRE 22 zones
│   ├── LocationService.swift       # CLLocationManager
│   ├── NoiseService.swift          # Overpass API, cancelFetch()
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
│   └── ZIPDemographicsSheet.swift  # ZIP demographics panel
└── Assets.xcassets/
```

### ContentView Key State Variables

```swift
@State var mapRegion: MKCoordinateRegion         // Replaces the original MapCameraPosition
@State var currentCenter: CLLocationCoordinate2D
@State var currentSpan: MKCoordinateSpan
@State var selectedCategory: CategoryType = .population
@State var highlightedZIPId: String?
@State var selectedZIP: ZIPCodeRegion?
@State var showZIPSheet = false                  // Controls ZIP sheet; uses isPresented instead of item
@State var pinnedLocation: CLLocationCoordinate2D?
@State var pinnedAddress = ""
@State var isLoadingScores = false
```

### HFMapView Key Callbacks (passed in by ContentView)

```swift
var onZIPTap:          (ZIPCodeRegion) -> Void
var onMapTap:          (CLLocationCoordinate2D) -> Void  // Currently a no-op
var onMapLongPress:    (CLLocationCoordinate2D) -> Void  // Long press -> GPS neighborhood
var onNoiseFetchCancel: () -> Void
```

---

## 10. Data Coverage

### Bay Area 9-County Coverage Status

| County | Schools | Crime | Fire | ZIP Boundaries |
|--------|---------|-------|------|----------------|
| Santa Clara | 36 schools | Full | Full | Census TIGER |
| Alameda | 29 schools | Full | Full | Census TIGER |
| San Francisco | 13 schools | Full | Full | Census TIGER |
| San Mateo | 16 schools | Full | Full | Census TIGER |
| Contra Costa | 17 schools | Full | Full | Census TIGER |
| Marin | 8 schools | Full | Full | Census TIGER |
| Sonoma | 5 schools | Limited | Full | Census TIGER |
| Napa | Limited | Limited | Limited | Census TIGER |
| Solano | Limited | Vallejo only | Limited | Census TIGER |

---

## 11. Known Issues & Rules

> After every bug fix, the lesson must be recorded here (to prevent repeating the same mistakes)

### Rules Quick Reference

| # | Rule | Summary |
|---|------|---------|
| R001 | CGImage premultiplied alpha | Use `CGContext.fill()` instead of manual byte format |
| R002 | SwiftUI `.overlay()` placement | Place inside ZStack, add `.allowsHitTesting(false)` |
| R003 | Xcode 16 auto-sync | Just place new files in the correct directory, no need to modify pbxproj |
| R004 | Shell heredoc `$` expansion | Use Python scp for strings containing `$`, avoid heredoc |
| R005 | Sidebar button clipping | Must use `ScrollView`, `maxHeight 380` |
| R006 | MKLocalSearch fuzziness | Use `MKLocalSearchCompleter` for real-time autocomplete |
| R007 | Gaussian decay units | Must use miles: `exp(-distMiles^2/radius^2)`, radius 2-5mi |
| R008 | Swift literal arrays >5K lines | SourceKitService OOM crash, use bundled JSON instead |
| R009 | PBXFileSystemSynchronized duplication | Manual pbxproj entry + auto-sync -> "Multiple commands produce" |
| R010 | `Int(Double.infinity)` crash | `guard value.isFinite` before all `Int(someDouble)` conversions |
| R011 | `.sheet(item:)` seamless switch | Use `.sheet(isPresented:)` + separate content state instead |

### Detailed Explanations

**R008 - Large Swift literal arrays crash Mac**
- Problem: 32941-line `ZIPCodeData.swift` (445 ZIPs embedded as Swift array literals) -> SourceKitService >10GB RAM, Mac crashes
- Lesson: **Never embed large datasets as Swift literals**, use bundled JSON loaded at runtime instead
- Solution: `bayarea_zips.json` (693KB) + `ZIPCodeData.swift` (65 lines) runtime parsing

**R010 - `Int(Double.infinity)` is undefined behavior in Swift**
- Problem: `electricService.lines` is empty -> `minLineDistDeg` stays `Double.infinity` -> `Int(infinity)` -> EXC_BAD_INSTRUCTION
- Swift does not perform safe conversion, it traps directly
- Lesson: Always `guard value.isFinite` before any Double->Int conversion, or use `min(cap, Int(value))` as defense
- Affected file: `ContentView.swift` `computeScores()` all branches

**R011 - `.sheet(item:)` dismisses and re-presents when item changes**
- Problem: When user taps another ZIP, `.sheet(item: $selectedZIP)` first dismisses the old sheet, then presents the new one -> animation flicker
- Solution: `@State var showZIPSheet = false` + `.sheet(isPresented: $showZIPSheet)` + read `selectedZIP` inside the content
- Key: `selectedZIP = newRegion` must come before `showZIPSheet = true` (batched in the same run loop)

### Current Known Limitations
- Overpass API times out (504) on Mac local testing; works fine on iOS device direct connection
- Crime heatmap is a Gaussian model estimate, not real per-street crime data
- School ratings are static hardcoded data, not from a real-time API
- Supportive Housing data is sparse in SF, Oakland, Berkeley
