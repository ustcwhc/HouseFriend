# Phase 2 Context: Real Crime Data

**Created:** 2026-03-22
**Phase Goal:** Crime heatmap renders real incident data from SF Open Data and Oakland CrimeWatch (plus San Jose and Berkeley), not Gaussian estimates

## Decisions

### 1. Heatmap Transition: Density Grid

**Decision:** Replace the hardcoded Gaussian model (21 hotspots + 11 safe zones in `CrimeTileOverlay`) with a **density grid** built from real API incidents.

**How it works:**
- Fetch real incidents from SODA APIs → build a spatial grid (e.g., 0.005° cells)
- Count incidents per grid cell → normalize to 0.0-1.0 intensity
- `crimeValue(lat:lon:)` interpolates from the grid instead of hardcoded hotspots
- Existing color mapping code (6-tier red gradient) remains unchanged
- Grid rebuilds when viewport changes significantly (beyond cached region)

**Coverage gaps:** Areas outside SF/Oakland/San Jose/Berkeley show a "Crime data not available for this area" message overlay — no Gaussian fallback, no fake data.

**Scoring:** Crime score in neighborhood report uses **real incident count** — more incidents = lower score. Replace the current `max(20, 100 - min(incidents.count, 80))` formula with a density-normalized score.

### 2. Crime Cluster UX: Grid-Cell Markers

**Decision:** When the "Details" toggle is enabled, show **numbered cluster markers** using the same density grid cells.

**How it works:**
- Each grid cell with incidents displays a numbered `MKAnnotation` marker showing the incident count
- Markers reuse the existing `CrimeMarker` model and `HFAnnotation` system
- **Tap action:** Tapping a cluster marker **zooms the map** into that area for more detail
- At high zoom levels, grid cells become small enough to show individual incident areas

**Visual design:** Numbered circles matching the competitor's pattern — white circle with count number, colored by severity (red for high count, orange for moderate, gray for low).

### 3. Multi-City Routing: Query All, Merge

**Decision:** Query **all available city APIs** for the current viewport and merge results into a single incident set.

**Cities for v1:**
- San Francisco — SF Open Data SODA API (`data.sfgov.org`, dataset `wg3w-h783`)
- Oakland — Oakland CrimeWatch SODA API (`data.oaklandca.gov`, dataset `ppgh-7dqv`)
- San Jose — **needs research** (verify Socrata availability, find dataset ID)
- Berkeley — **needs research** (verify Socrata availability, find dataset ID)

**Implementation:**
- `CrimeService` maintains a registry of city endpoints with bounding boxes
- For each viewport, determine which cities overlap and fire parallel requests
- Merge incident arrays, deduplicate if needed, build unified density grid
- Each city endpoint has its own field mapping (column names vary between datasets)

**Uncovered areas:** Show "Crime data not available for this area" message when no city API covers the viewport.

### 4. Data Recency: 90-Day Rolling Window, Equal Weight

**Decision:** Fetch incidents from the **last 90 days** with **no temporal weighting** — all incidents within the window count equally.

**Implementation:**
- SODA `$where` clause: `report_datetime > '${90_days_ago}'`
- Recency label in neighborhood report: "Based on incidents from last 90 days"
- Cache TTL: 24 hours (from Phase 1 ResponseCache configuration)
- No decay function — simpler to implement and explain to users

## Code Context

### Existing Assets to Reuse
- `CrimeService.swift` — Already has SF Open Data API call structure, `CrimeIncident` model, `CrimeStats` struct, `fetchNear(lat:lon:)` pattern
- `CrimeTileOverlay.swift` — Tile rendering pipeline (256x256, zoom 7-17, background thread), color mapping, alpha formula. Replace `crimeValue()` internals, keep the renderer
- `CrimeMarker.swift` — `CrimeType` enum with system images and colors, `CrimeMarker` struct with coordinate/type/count/daysAgo
- `ContentView.swift` — `showCrimeDetails` toggle, `refreshCrimeIncidents()` function, crime sidebar toggle UI
- `HFMapView.swift` — Crime annotation rendering in `updateAnnotations`, `MKMarkerAnnotationView` styling for crime markers
- `ResponseCache.swift` — Cache layer `.crime` with 24hr TTL, grid-cell cache keys via `cacheKey(layer:lat:lon:)`
- `ScoringService.swift` — `crimeScore(stats:)` pass-through that returns `ScoreResult`

### Key Integration Points
- `CrimeTileOverlay.crimeValue(lat:lon:)` — Replace Gaussian formula with density grid lookup
- `CrimeService.fetchNear(lat:lon:)` — Expand to query multiple cities, merge results
- `ContentView.refreshCrimeIncidents()` — Replace mock generation with real incident clustering
- `ScoringService.crimeScore()` — Update to use real incident density scoring

### New Components Needed
- City endpoint registry (dataset IDs, base URLs, field mappings per city)
- Density grid builder (incidents → spatial grid)
- Cluster marker generator (grid cells → numbered annotations)
- "No data available" overlay for uncovered areas
- Field-presence validation with error banner (CRIME-06)

## Scope Boundary

**In scope (Phase 2):** SF + Oakland + San Jose + Berkeley crime APIs, density grid heatmap, cluster markers, scoring, recency labels, error handling
**Out of scope:** Other Bay Area cities beyond these 4, ML gap-filling (ADV-06), historical trends (ADV-01), crime type filtering UI

## Deferred Ideas

- Add more Bay Area cities (Fremont, Richmond, etc.) in a future phase if the 4-city pattern works well
- Crime type filtering (show only property crime, only violent crime) — good v2 feature
- Historical trend view per location — requires time-series storage, deferred to ADV-01

## Research Needs

Phase 2 research should investigate:
1. **San Jose crime data API** — Does San Jose use Socrata? What's the dataset ID and field schema?
2. **Berkeley crime data API** — Same questions for Berkeley
3. **Oakland field schema validation** — Verify `ppgh-7dqv` field names match what we expect
4. **Socrata app token cross-instance** — Does one token work across all Socrata portals, or do we need separate registration per city?

---
*Context created: 2026-03-22 after discuss-phase*
