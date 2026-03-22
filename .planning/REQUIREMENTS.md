# Requirements: HouseFriend

**Defined:** 2026-03-22
**Core Value:** Users can instantly visualize and score any Bay Area neighborhood across 10 safety/quality dimensions from a single map interface

## v1 Requirements

Requirements for App Store v1.0 release. Each maps to roadmap phases.

### Infrastructure

- [x] **INFRA-01**: App has a shared ResponseCache (memory + disk) with per-layer TTLs for all API responses
- [x] **INFRA-02**: Cache prevents redundant API calls when user pans/zooms within cached region
- [x] **INFRA-03**: Cache entries expire based on data freshness (30min earthquake, 1hr air quality, 24hr crime, permanent for bundled data)

### Crime Data

- [ ] **CRIME-01**: Crime heatmap renders from real SF Open Data SODA API incidents, not Gaussian estimates
- [ ] **CRIME-02**: Crime heatmap renders from real Oakland CrimeWatch SODA API incidents for Oakland/East Bay
- [ ] **CRIME-03**: API requests include explicit `$limit` and `$where` bounding box to avoid silent 1,000-row truncation
- [ ] **CRIME-04**: Requests include registered Socrata app token to avoid shared IP throttling
- [ ] **CRIME-05**: Multi-city routing selects SF vs Oakland endpoint based on coordinate location
- [ ] **CRIME-06**: Field-presence validation surfaces visible error banner on schema changes instead of silently falling back to mock data
- [ ] **CRIME-07**: Crime layer shows data recency label ("Based on incidents from last 90 days")
- [ ] **CRIME-08**: Crime detail toggle shows numbered cluster markers (incident counts per area) on top of heatmap when enabled
- [ ] **CRIME-09**: Cluster markers aggregate by area and display crime count numbers (similar to competitor's Details toggle)

### School Data

- [ ] **SCHOOL-01**: School pins display on map at zoom level >= 13 with school name and rating number on the pin label (e.g., "Santa Clara High (10)")
- [ ] **SCHOOL-02**: School pins are color-coded by rating level (green=high, blue=mid, orange/red=low)
- [ ] **SCHOOL-03**: Tap school pin shows detail sheet with name, type (elementary/middle/high), rating, and CAASPP test score summary
- [ ] **SCHOOL-04**: School ratings sourced from CDE California Dashboard (CAASPP) data bundled at build time
- [ ] **SCHOOL-05**: Build-time Python script fetches CDE XLSX + CA Public Schools GeoJSON, joins by CDS code, outputs gzip'd JSON bundle
- [ ] **SCHOOL-06**: School scoring in neighborhood report uses real rating data instead of placeholder

### Loading & Polish

- [ ] **POLISH-01**: All 10 layers show a loading spinner when switching (consistent with existing noise layer pattern)
- [ ] **POLISH-02**: Each layer grade in neighborhood report includes 1-2 sentence descriptive text explaining what the grade means
- [ ] **POLISH-03**: Neighborhood report shows data source attribution per layer (e.g., "SF Open Data", "USGS", "CDE")
- [ ] **POLISH-04**: Each layer has an info button (?) that opens a modal with "What is it?", "Data source", and "Limitations" sections
- [ ] **POLISH-05**: Crime layer info modal includes data accuracy disclaimer and privacy obfuscation note (coordinates anonymized to nearest intersection)
- [ ] **POLISH-06**: Superfund pins show NPL status (active vs. deleted/cleaned-up) with color coding (green = deleted from NPL)
- [ ] **POLISH-07**: Superfund detail sheet includes a deep link to the EPA website for each site

### Dark Mode

- [ ] **DARK-01**: App supports iOS system dark mode toggle
- [ ] **DARK-02**: NoiseSmokeRenderer resolves colors dynamically at draw time using current UITraitCollection
- [ ] **DARK-03**: CrimeTileOverlay heatmap tiles render correctly in both light and dark mode
- [ ] **DARK-04**: All SwiftUI views use semantic system colors (no hardcoded color literals)
- [ ] **DARK-05**: Dark mode change triggers overlay renderer refresh (setNeedsDisplay or remove/re-add)

### Saved Addresses

- [ ] **SAVE-01**: User can save/favorite an address from the neighborhood report panel (star button)
- [ ] **SAVE-02**: User can view a list of saved addresses accessible from the toolbar
- [ ] **SAVE-03**: Saved addresses persist across app launches (SwiftData persistence)
- [ ] **SAVE-04**: Saved addresses display as distinct pins on the map
- [ ] **SAVE-05**: User can delete a saved address from the list

### Share Feature

- [ ] **SHARE-01**: User can share a neighborhood score card as an image from the report panel
- [ ] **SHARE-02**: Score card image includes: address, map thumbnail, per-layer A-F grades, app branding
- [ ] **SHARE-03**: Map thumbnail captures live MKMapView with all visible overlays (using drawHierarchy, not MKMapSnapshotter)
- [ ] **SHARE-04**: Share uses UIActivityViewController (system share sheet)
- [ ] **SHARE-05**: Score card renders correctly in both light and dark mode

### App Store Preparation

- [ ] **STORE-01**: PrivacyInfo.xcprivacy manifest includes UserDefaults (CA92.1) and CoreLocation declarations
- [ ] **STORE-02**: Privacy policy hosted at accessible URL and linked from within the app
- [ ] **STORE-03**: App icon at 1024x1024 plus all required sizes
- [ ] **STORE-04**: App Store screenshots for 6.9" and 6.5" iPhone sizes showing real data
- [ ] **STORE-05**: App Store Connect metadata complete (description, keywords, privacy labels, age rating, export compliance)
- [ ] **STORE-06**: NSPhotoLibraryAddUsageDescription added to Info.plist (for share/save image)
- [ ] **STORE-07**: TestFlight internal beta test completed before submission

### Data Expansion

- [ ] **DATA-01**: Supportive housing data expanded to include SF, Oakland, Berkeley, San Mateo using HUD data + non-profit directories (LifeMoves, Abode Services, HomeFirst, HomeKey, CityTeam)
- [ ] **DATA-02**: Electric lines expanded using HIFLD (Homeland Infrastructure Foundation-Level Data) to include 69kV+ lines
- [ ] **DATA-03**: Electric lines layer adds substation locations as pins alongside transmission lines

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Layout & Platform

- **PLAT-01**: iPad-optimized split-view layout with dedicated sidebar
- **PLAT-02**: iCloud sync for saved addresses across devices

### Advanced Features

- **ADV-01**: Historical crime trend view (crime over time for a location)
- **ADV-02**: Additional data layers (transit scores, walkability, flood zones)
- **ADV-03**: Neighborhood comparison view (side-by-side score cards for 2-3 addresses)
- **ADV-04**: Population layer multi-zoom granularity (County → ZIP → Census Tract → Census Block)
- **ADV-05**: School attendance boundary overlays (which school an address attends)
- **ADV-06**: Crime ML gap-filling for regions with sparse reporting data
- **ADV-07**: Aviation noise data from Bureau of Transportation model

## Out of Scope

| Feature | Reason |
|---------|--------|
| Android version | iOS-first strategy; no cross-platform for v1 |
| User accounts / authentication | All data is local; no backend needed for v1 |
| Real-time crime alerts / push notifications | Requires server infrastructure, background location; this is a reference app, not monitoring |
| User-submitted crime reports | Requires moderation, backend, legal exposure; value prop is authoritative official data |
| Social features | Requires accounts and backend; system share sheet covers the sharing use case |
| Individual crime incident dots (unpaginated pins) | Research shows this increases perceived danger and racial bias without improving decisions; use aggregated cluster counts instead |
| Paid API subscriptions (GreatSchools, etc.) | Constraint: zero paid APIs for v1; free government data matches or exceeds quality |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| INFRA-01 | Phase 1 | Complete |
| INFRA-02 | Phase 1 | Complete |
| INFRA-03 | Phase 1 | Complete |
| CRIME-01 | Phase 2 | Pending |
| CRIME-02 | Phase 2 | Pending |
| CRIME-03 | Phase 2 | Pending |
| CRIME-04 | Phase 2 | Pending |
| CRIME-05 | Phase 2 | Pending |
| CRIME-06 | Phase 2 | Pending |
| CRIME-07 | Phase 2 | Pending |
| CRIME-08 | Phase 2 | Pending |
| CRIME-09 | Phase 2 | Pending |
| SCHOOL-01 | Phase 3 | Pending |
| SCHOOL-02 | Phase 3 | Pending |
| SCHOOL-03 | Phase 3 | Pending |
| SCHOOL-04 | Phase 3 | Pending |
| SCHOOL-05 | Phase 3 | Pending |
| SCHOOL-06 | Phase 3 | Pending |
| DARK-01 | Phase 4 | Pending |
| DARK-02 | Phase 4 | Pending |
| DARK-03 | Phase 4 | Pending |
| DARK-04 | Phase 4 | Pending |
| DARK-05 | Phase 4 | Pending |
| POLISH-01 | Phase 5 | Pending |
| POLISH-02 | Phase 5 | Pending |
| POLISH-03 | Phase 5 | Pending |
| POLISH-04 | Phase 5 | Pending |
| POLISH-05 | Phase 5 | Pending |
| POLISH-06 | Phase 5 | Pending |
| POLISH-07 | Phase 5 | Pending |
| DATA-01 | Phase 5 | Pending |
| DATA-02 | Phase 5 | Pending |
| DATA-03 | Phase 5 | Pending |
| SAVE-01 | Phase 6 | Pending |
| SAVE-02 | Phase 6 | Pending |
| SAVE-03 | Phase 6 | Pending |
| SAVE-04 | Phase 6 | Pending |
| SAVE-05 | Phase 6 | Pending |
| SHARE-01 | Phase 7 | Pending |
| SHARE-02 | Phase 7 | Pending |
| SHARE-03 | Phase 7 | Pending |
| SHARE-04 | Phase 7 | Pending |
| SHARE-05 | Phase 7 | Pending |
| STORE-01 | Phase 8 | Pending |
| STORE-02 | Phase 8 | Pending |
| STORE-03 | Phase 8 | Pending |
| STORE-04 | Phase 8 | Pending |
| STORE-05 | Phase 8 | Pending |
| STORE-06 | Phase 8 | Pending |
| STORE-07 | Phase 8 | Pending |

**Coverage:**
- v1 requirements: 51 total
- Mapped to phases: 51
- Unmapped: 0

---
*Requirements defined: 2026-03-22*
*Last updated: 2026-03-22 — refined with competitor analysis insights*
