# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-22)

**Core value:** Users can instantly visualize and score any Bay Area neighborhood across 10 safety/quality dimensions from a single map interface
**Current focus:** Phase 1 — API Caching Foundation

## Current Position

Phase: 1 of 8 (API Caching Foundation)
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-03-22 — Roadmap created; 43 requirements mapped across 8 phases

Progress: [░░░░░░░░░░] 0%

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

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Init]: SwiftData chosen over UserDefaults for saved addresses (iOS 17+ type safety, zero encode/decode boilerplate)
- [Init]: CDE Dashboard XLSX bundled at build time via Python script instead of GreatSchools API ($52.50/mo paid tier avoided)
- [Init]: `drawHierarchy` on live MKMapView chosen over MKMapSnapshotter for share image (snapshotter omits custom overlays)

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 2]: Oakland CrimeWatch dataset (`ppgh-7dqv`) field schema must be validated against a live API response before hard-coding field mappings — schema confirmed different from SF dataset
- [Phase 2]: Verify whether Socrata app token registered at data.sfgov.org works on data.oaklandca.gov or requires separate registration
- [Phase 3]: CDE XLSX join key (CDS code) format must be validated against CA Public Schools GeoJSON before building the build-time Python script
- [Phase 7]: Verify whether HFMapView Coordinator already implements `mapViewDidFinishRenderingMap` delegate callback (required for safe share image capture timing)

## Session Continuity

Last session: 2026-03-22
Stopped at: Roadmap and STATE.md created; ready to plan Phase 1
Resume file: None
