---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: unknown
stopped_at: Completed 02.2-01-PLAN.md
last_updated: "2026-03-25T06:09:21.595Z"
progress:
  total_phases: 10
  completed_phases: 3
  total_plans: 10
  completed_plans: 9
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-22)

**Core value:** Users can instantly visualize and score any Bay Area neighborhood across 10 safety/quality dimensions from a single map interface
**Current focus:** Phase 02.2 — crime-cluster-ux

## Current Position

Phase: 02.2 (crime-cluster-ux) — EXECUTING
Plan: 2 of 2

## Performance Metrics

**Velocity:**

- Total plans completed: 0
- Average duration: —
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 01 P01 | 4min | 1 tasks | 2 files |
| Phase 01 P02 | 5min | 2 tasks | 5 files |
| Phase 02 P01 | 4min | 2 tasks | 3 files |
| Phase 02 P02 | 4min | 2 tasks | 3 files |
| Phase 02.1 P01 | 4min | 2 tasks | 4 files |
| Phase 02.1 P03 | 11min | 2 tasks | 1 files |
| Phase 02.1 P02 | 12min | 3 tasks | 1 files |
| Phase 02.1 P04 | 2min | 1 tasks | 4 files |
| Phase 01-server-side-scoping P01 | 2 | 2 tasks | 3 files |
| Phase 02.2 P01 | 5min | 2 tasks | 4 files |

## Accumulated Context

### Roadmap Evolution

- Phase 02.1 inserted after Phase 2: Mapbox Migration — Replace Apple MapKit with Mapbox SDK for all 10 map layers, overlays, annotations, and gesture handling (URGENT)

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Init]: SwiftData chosen over UserDefaults for saved addresses (iOS 17+ type safety, zero encode/decode boilerplate)
- [Init]: CDE Dashboard XLSX bundled at build time via Python script instead of GreatSchools API ($52.50/mo paid tier avoided)
- [Init]: `drawHierarchy` on live MKMapView chosen over MKMapSnapshotter for share image (snapshotter omits custom overlays)
- [Phase 01]: NSCache memory + FileManager disk two-level cache with injectable dateProvider for testable TTL
- [Phase 01]: Extracted static parse methods for cache/network code reuse in all services
- [Phase 01]: NoiseService caches only Overpass dynamic fetches, not bundled static road data
- [Phase 02]: Oakland dataset ym6k-rx7a used (NOT ppgh-7dqv which has no coordinates)
- [Phase 02]: Density-normalized scoring: peak cell count / 50 baseline, mapped to 20-100 range
- [Phase 02]: NSLock for thread-safe CrimeTileOverlay.densityGrid access (background tile threads)
- [Phase 02]: Overlay replacement (remove+add) for tile invalidation on grid change
- [Phase 02.1]: Fully qualify MapboxMaps.Map/MapReader/MapStyle to avoid SwiftUI Map ambiguity when MapKit is co-imported
- [Phase 02.1]: spanForZoom/zoomForSpan converters bridge Mapbox zoom levels with existing MKCoordinateSpan-based services
- [Phase 02.1]: Use @_spi(Experimental) import MapboxMaps for declarative GeoJSONSource; rgba() CSS strings for expression colors; fully qualify MapboxMaps.MapContent to resolve ambiguity
- [Phase 02.1]: rgba string literals for expression colors (StyleColor init returns optional)
- [Phase 02.1]: Helper functions for layers needing filter property (not chainable in MapContent builder)
- [Phase 02.1]: Moved CrimeHotspot struct to CrimeService.swift (co-located with service)
- [Phase 02.1]: Replaced import MapKit with import CoreLocation in HFMapView after full Mapbox migration
- [Phase 01-server-side-scoping]: patch exit code 2 treated as no-op — allows placeholder patch before 01-02 populates real diff
- [Phase 01-server-side-scoping]: SessionStart hook appended to existing hooks array, not a second SessionStart element
- [Phase 02.2]: Vehicle keywords checked before property in CrimeSeverity classifier for correct priority
- [Phase 02.2]: Heatmap opacity 0.55 balances severity visualization with street name readability
- [Phase 02.2]: crimeIncidentFC carries full metadata (weight/severity/category/description/date) for reuse by cluster layers

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 2]: Oakland CrimeWatch dataset (`ppgh-7dqv`) field schema must be validated against a live API response before hard-coding field mappings — schema confirmed different from SF dataset
- [Phase 2]: Verify whether Socrata app token registered at data.sfgov.org works on data.oaklandca.gov or requires separate registration
- [Phase 3]: CDE XLSX join key (CDS code) format must be validated against CA Public Schools GeoJSON before building the build-time Python script
- [Phase 7]: Verify whether HFMapView Coordinator already implements `mapViewDidFinishRenderingMap` delegate callback (required for safe share image capture timing)

## Session Continuity

Last session: 2026-03-25T06:09:21.593Z
Stopped at: Completed 02.2-01-PLAN.md
Resume file: None
