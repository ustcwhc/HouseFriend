# Roadmap: HouseFriend

## Overview

HouseFriend's core 10-layer map is complete. This milestone replaces placeholder data with real government API feeds, adds dark mode renderer support, implements saved addresses and share, then submits to the App Store. Phases follow strict dependency order: caching before API calls, real data before share card, dark mode before screenshots, all features before submission.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: API Caching Foundation** - Shared ResponseCache (memory + disk, per-layer TTLs) that all API services use (completed 2026-03-24)
- [ ] **Phase 2: Real Crime Data** - CrimeService wired to SF Open Data and Oakland CrimeWatch SODA APIs
- [x] **Phase 02.1: Mapbox Migration (INSERTED)** - Replace Apple MapKit with Mapbox SDK for all 10 map layers (completed 2026-03-23)
- [ ] **Phase 3: School Data** - SchoolService wired to CDE Dashboard data with school pins on map
- [ ] **Phase 4: Dark Mode** - Custom overlay renderers updated for dynamic color and system dark mode toggle
- [ ] **Phase 5: Loading & Layer Polish** - Spinners on all layers, descriptive report text, data attribution, expanded data sets
- [ ] **Phase 6: Saved Addresses** - Favoriting, SwiftData persistence, map pins, and list management
- [ ] **Phase 7: Share Feature** - Score card image generation and system share sheet
- [ ] **Phase 8: App Store Preparation** - Privacy manifest, policy, icon, screenshots, metadata, TestFlight

## Phase Details

### Phase 1: API Caching Foundation
**Goal**: All network-dependent layers read from and write to a shared cache before making live API requests
**Depends on**: Nothing (first phase)
**Requirements**: INFRA-01, INFRA-02, INFRA-03
**Success Criteria** (what must be TRUE):
  1. Panning the map within a region that was recently fetched does not trigger a new network request for that layer
  2. Cache entries for earthquake data expire after 30 minutes; air quality after 1 hour; crime after 24 hours; bundled static data never expires
  3. Fetching the same location twice within the TTL window returns cached data without any network activity (verifiable via console or proxy)
**Plans:** 2/2 plans complete
Plans:
- [x] 01-01-PLAN.md — ResponseCache singleton with two-level cache (NSCache + disk) and per-layer TTLs (TDD)
- [x] 01-02-PLAN.md — Integrate ResponseCache into all 5 network services

### Phase 2: Real Crime Data
**Goal**: Crime heatmap renders real incident data from SF Open Data and Oakland CrimeWatch, not Gaussian estimates
**Depends on**: Phase 1
**Requirements**: CRIME-01, CRIME-02, CRIME-03, CRIME-04, CRIME-05, CRIME-06, CRIME-07, CRIME-08, CRIME-09
**Success Criteria** (what must be TRUE):
  1. The crime heatmap in a San Francisco neighborhood reflects real SFPD incident coordinates from the past 90 days
  2. The crime heatmap in an Oakland neighborhood reflects real Oakland CrimeWatch incident coordinates, not the SF endpoint
  3. A visible recency label appears in the neighborhood report ("Based on incidents from last 90 days")
  4. When the Detail toggle is enabled, numbered cluster markers appear over the heatmap showing incident counts per area
  5. A visible error banner appears if the API response is missing expected fields, instead of silently showing placeholder data
**Plans:** 2 plans
Plans:
- [x] 02-01-PLAN.md — CityEndpoint + DensityGrid models, CrimeService multi-city fetch with field validation
- [x] 02-02-PLAN.md — CrimeTileOverlay density grid rendering, cluster markers, ContentView wiring

### Phase 02.1: Mapbox Migration (INSERTED)

**Goal:** Replace Apple MapKit (MKMapView) with Mapbox SDK for all 10 map layers, overlays, annotations, and gesture handling. Enables dark map tiles, custom styling, and OpenStreetMap base map.
**Requirements**: MAP-01, MAP-02, MAP-03, MAP-04, MAP-05, MAP-06, MAP-07, MAP-08, MAP-09, MAP-10
**Depends on:** Phase 2
**Success Criteria** (what must be TRUE):
  1. App builds with Mapbox Maps SDK v11 SPM dependency
  2. All 10 data layers render correctly through Mapbox GeoJSON sources and layers
  3. Tap and long-press gestures fire callbacks to ContentView
  4. Crime heatmap renders as GPU-accelerated HeatmapLayer glow on dark tiles
  5. Noise roads render with smoke/blur effect via stacked LineLayer
  6. 445 ZIP polygons render without lag (Mapbox vector tile engine handles viewport culling)
  7. All annotation types (schools, superfund, earthquake, housing) are tappable
  8. CrimeTileOverlay.swift and NoiseSmokeRenderer.swift are deleted
**Plans:** 4/4 plans complete

Plans:
- [x] 02.1-01-PLAN.md — Mapbox SPM dependency, token loading, ZoomTier migration, HFMapView rewrite, ContentView Viewport wiring
- [x] 02.1-02-PLAN.md — Polygon/polyline layers (fire, electric, odor, ZIP, noise smoke)
- [x] 02.1-03-PLAN.md — Crime HeatmapLayer and all annotation types (schools, superfund, earthquake, housing, clusters, pin)
- [x] 02.1-04-PLAN.md — Cleanup (delete old renderers, move Hotspot type) and visual verification checkpoint

### Phase 3: School Data
**Goal**: School pins appear on the map with real CDE rating data, color-coded by level, and neighborhood report school scoring uses real grades
**Depends on**: Phase 1
**Requirements**: SCHOOL-01, SCHOOL-02, SCHOOL-03, SCHOOL-04, SCHOOL-05, SCHOOL-06
**Success Criteria** (what must be TRUE):
  1. At zoom level 13 or higher, school pins appear with school name and rating number on the label (e.g., "Santa Clara High (10)")
  2. School pins are color-coded by rating level (green=high, blue=mid, orange/red=low)
  3. Tapping a school pin shows a detail sheet with name, type, rating, and CAASPP test score summary
  4. The neighborhood report school grade reflects real CDE Dashboard data, not a placeholder value
  5. The build-time Python script runs without errors and produces a gzip'd JSON bundle used at runtime
**Plans**: TBD

### Phase 4: Dark Mode
**Goal**: The app fully supports iOS system dark mode, including all custom overlay renderers and SwiftUI views
**Depends on**: Phase 2, Phase 3
**Requirements**: DARK-01, DARK-02, DARK-03, DARK-04, DARK-05
**Success Criteria** (what must be TRUE):
  1. Toggling iOS dark mode in Settings causes the app UI (all SwiftUI views) to switch appearance without restart
  2. The noise smoke overlay renders with correct dark-mode colors after toggling system appearance
  3. The crime heatmap tiles render correctly in both light and dark mode without visual artifacts
  4. Switching system appearance while the map is visible causes overlays to refresh within one render cycle
**Plans**: TBD

### Phase 5: Loading & Layer Polish
**Goal**: All layers show loading feedback, every layer has an info modal with description/source/limitations, data is expanded, and existing layers are enhanced with competitor-inspired details
**Depends on**: Phase 2, Phase 3
**Requirements**: POLISH-01, POLISH-02, POLISH-03, POLISH-04, POLISH-05, POLISH-06, POLISH-07, DATA-01, DATA-02, DATA-03
**Success Criteria** (what must be TRUE):
  1. Toggling any of the 10 layers shows a loading spinner while data loads (consistent with the existing noise layer behavior)
  2. Each layer grade in the neighborhood report includes 1-2 sentences explaining what the grade means in plain language
  3. The neighborhood report shows a data source attribution per layer (e.g., "SF Open Data", "USGS", "CDE")
  4. Each layer has an info (?) button that opens a modal with "What is it?", "Data source", and "Limitations" sections
  5. The crime layer info modal includes data accuracy disclaimer and privacy obfuscation note
  6. Superfund pins show NPL status (active vs. deleted) with color coding, and detail sheet links to EPA website
  7. The supportive housing layer includes data from SF, Oakland, Berkeley, and San Mateo (sourced from HUD + non-profits)
  8. The electric lines layer includes HIFLD 69kV+ lines and substation pins
**Plans**: TBD

### Phase 6: Saved Addresses
**Goal**: Users can save addresses from the report panel, view and delete them from a list, and see them as pins on the map
**Depends on**: Phase 2, Phase 3
**Requirements**: SAVE-01, SAVE-02, SAVE-03, SAVE-04, SAVE-05
**Success Criteria** (what must be TRUE):
  1. A star button in the neighborhood report panel saves the current address
  2. Saved addresses appear in a list accessible from the toolbar
  3. Saved addresses are still present in the list after closing and reopening the app
  4. Saved addresses appear as distinct pins on the map distinct from search result pins
  5. Deleting a saved address from the list also removes its pin from the map
**Plans**: TBD

### Phase 7: Share Feature
**Goal**: Users can share a neighborhood score card image from the report panel that includes the map with all visible overlays
**Depends on**: Phase 4, Phase 5, Phase 6
**Requirements**: SHARE-01, SHARE-02, SHARE-03, SHARE-04, SHARE-05
**Success Criteria** (what must be TRUE):
  1. The neighborhood report panel has a share button that triggers the iOS system share sheet
  2. The shared image shows the address, a live map thumbnail with all visible overlays rendered, per-layer A-F grades, and app branding
  3. The map thumbnail in the shared image shows crime heatmap, noise smoke, and other active overlays — not a plain base map
  4. The share card image looks correct in both light and dark mode
**Plans**: TBD

### Phase 8: App Store Preparation
**Goal**: The app is accepted by App Store Connect and approved for public distribution
**Depends on**: Phase 4, Phase 5, Phase 6, Phase 7
**Requirements**: STORE-01, STORE-02, STORE-03, STORE-04, STORE-05, STORE-06, STORE-07
**Success Criteria** (what must be TRUE):
  1. Xcode's Privacy Report shows a complete PrivacyInfo.xcprivacy with UserDefaults (CA92.1) and CoreLocation declarations
  2. The app contains an accessible link to a privacy policy hosted at a reachable public URL
  3. The App Store Connect listing has a 1024x1024 icon, 6.9" and 6.5" screenshots showing real neighborhood data, complete metadata, and privacy nutrition labels
  4. At least one internal tester completes the TestFlight beta without crashing and confirms core flows work
  5. App Store Connect submission passes automated validation (no missing manifest, no missing usage descriptions)
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 02.1 → 3 → 4 → 5 → 6 → 7 → 8

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. API Caching Foundation | 2/2 | Complete   | 2026-03-24 |
| 2. Real Crime Data | 2/2 | Complete | - |
| 02.1. Mapbox Migration | 4/4 | Complete   | 2026-03-23 |
| 3. School Data | 0/TBD | Not started | - |
| 4. Dark Mode | 0/TBD | Not started | - |
| 5. Loading & Layer Polish | 0/TBD | Not started | - |
| 6. Saved Addresses | 0/TBD | Not started | - |
| 7. Share Feature | 0/TBD | Not started | - |
| 8. App Store Preparation | 0/TBD | Not started | - |
