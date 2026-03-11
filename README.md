# HouseFriend

> A Bay Area "Neighborhood Health Report" — overlay 10 layers of real data on a map to help users see the full picture of safety, environment, schools, and noise before buying or renting.
>
> Comparable product: App Store "Neighborhood Check" (id6446656055)
>
> GitHub: ustcwhc/HouseFriend

---

## Product Vision

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

## 10 Data Layers

| # | Layer | Rendering | Data Source | Coverage |
|---|-------|-----------|-------------|----------|
| 1 | Crime | `CrimeTileOverlay` (MKTileOverlay, background CGContext rendering) | Gaussian model | Full Bay Area |
| 2 | Noise | `NoiseSmokeRenderer` (custom MKOverlayRenderer, 4-layer smoke effect) | Bundled roads + OSM Overpass API | Full Bay Area |
| 3 | Schools | `MKAnnotation` pins | Hardcoded 130+ schools | All 9 Bay Area counties |
| 4 | Superfund | `MKAnnotation` pins | Hardcoded 62 sites | Full Bay Area |
| 5 | Earthquake | `MKCircle` scaled by magnitude | USGS real-time API | Real-time |
| 6 | Fire Hazard | `MKPolygon` | Hardcoded 22 CAL FIRE zones | Full Bay Area |
| 7 | Electric Lines | `MKPolyline` | Hardcoded PG&E transmission corridors | Main lines only |
| 8 | Supportive Housing | `MKAnnotation` pins | Hardcoded | Limited coverage |
| 9 | Air Quality/Odor | `MKPolygon` | Open-Meteo API + hardcoded industrial zones | Full Bay Area |
| 10 | Population | `MKPolygon` ZIP polygons + demographics sheet | Census TIGER 2023 JSON | 445 ZIPs |

---

## Feature Spec

### Complete User Journey

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

### Population Layer (Core Feature)

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

### Address Search

- Autocomplete suggestions appear after the 1st character typed (`MKLocalSearchCompleter`)
- Dropdown list has two tiers: fuzzy autocomplete (instant) + full results (with coordinates)
- Tap any suggestion -> map flies to that address (span ~ 0.03 deg)
- Red pin appears on the map, bottom panel expands with Neighborhood Report
- Bay Area results are prioritized

### Crime Layer

**MKTileOverlay Rendering Spec**
- Background thread computes a 64x64 pixel heatmap for each Web Mercator tile (z/x/y)
- `CrimeTileOverlay.crimeValue(lat:lon:) -> Double` is the standard API
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

### Noise Layer

- Bundled `bayarea_roads.json.gz` (514 KB) for instant rendering of major roads + railways
- Two-tier loading: static data at City zoom, Overpass detail at Neighborhood zoom
- Dark smoke effect (NoiseSmokeRenderer): 4-layer haze scaled by dB level
- Railways rendered with dashed pattern (Caltrain, BART, freight at 70-75 dB)

### Neighborhood Report Bottom Panel

**Trigger: Long-press on map** (0.45s) -> pin drops -> bottom panel expands

**Auto-closes when switching layers** (`onChange(of: selectedCategory)` clears `pinnedLocation`)

**Score Computation Notes**
- All `Double -> Int` conversions must first `guard value.isFinite` (R010)
- `electricLines` branch: give 75 score + "Data loading..." when no data
- `fireHazard` branch: `minDist` can be infinity, use `safeMinDist`

### Loading Strategy

**Lazy Loading**
- On app launch, only Population is loaded (JSON parsing, ~0.1s)
- Other layers are loaded on switch via `loadLayerIfNeeded()`
- Already-loaded layers have an `isLoaded: Bool` flag to prevent duplicate requests

**Per-Layer Loading Strategy**

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

## Status

### Completed Features

**UI**
- [x] Right-side vertical sidebar (10 layer toggle buttons)
- [x] Top address search bar (fuzzy autocomplete)
- [x] Bottom Neighborhood Report panel (long-press trigger)
- [x] Score cards (progress ring + A/B/C/D/F letter rating)
- [x] Legend, zoom buttons, location button, active layer chip

**Map Layers**
- [x] Crime: MKTileOverlay pixel heatmap
- [x] Noise: Bundled roads + Overpass detail, smoke effect rendering, loading spinner
- [x] Schools: 130+ schools with tap detail
- [x] Superfund: 62 sites
- [x] Earthquake: USGS real-time
- [x] Fire Hazard: 22 CAL FIRE zones
- [x] Electric Lines, Supportive Housing, Air Quality
- [x] Population: 445 ZIPs with demographics sheet

**Data**
- [x] Full 9-county Bay Area coverage
- [x] 445 Bay Area ZIP polygons (Census TIGER 2023)
- [x] ZoomTier-based visibility filtering

### Pending Features

**High Priority**
- [ ] Loading Animation: Show spinner overlay when switching layers (noise layer done, others pending)
- [ ] Supportive Housing Expansion: Add SF, Oakland, Berkeley, San Mateo data

**Medium Priority**
- [ ] Crime Details Real Data: Integrate SF Open Data, Oakland Crime API
- [ ] School Rating Data: Integrate GreatSchools API or CA School Dashboard
- [ ] Electric Lines Expansion: Add sub-115kV distribution lines
- [ ] Neighborhood Report Enhancement: Descriptive text for each layer

**Low Priority**
- [ ] Dark mode support
- [ ] iPad layout optimization
- [ ] Share feature (screenshot + score card image generation)
- [ ] Saved/favorited addresses

---

## Data Coverage

### Bay Area 9-County Status

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
