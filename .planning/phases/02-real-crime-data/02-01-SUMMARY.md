---
phase: 02-real-crime-data
plan: 01
subsystem: api
tags: [socrata, soda-api, crime-data, density-grid, multi-city, geojson]

# Dependency graph
requires:
  - phase: 01-api-caching
    provides: ResponseCache with .crime layer (24hr TTL) and cacheKey generation
provides:
  - CityEndpoint registry with SF and Oakland SODA API configurations
  - DensityGrid spatial data structure for heatmap rendering
  - Multi-city CrimeService with real SF + Oakland data fetching
  - Field validation that surfaces errors instead of mock fallback
  - Density-normalized crime scoring
affects: [02-02-PLAN, crime-tile-overlay, hfmapview, contentview]

# Tech tracking
tech-stack:
  added: []
  patterns: [multi-city-endpoint-registry, density-grid-spatial, dispatch-group-parallel-fetch, geojson-coordinate-parsing]

key-files:
  created:
    - HouseFriend/Models/CityEndpoint.swift
    - HouseFriend/Models/DensityGrid.swift
  modified:
    - HouseFriend/Services/CrimeService.swift

key-decisions:
  - "Oakland dataset ym6k-rx7a used (NOT ppgh-7dqv which has no coordinates)"
  - "Density-normalized scoring: peak cell count / 50 baseline, mapped to 20-100 score range"
  - "Cache stores merged multi-endpoint JSON with endpoint names for correct re-parsing"
  - "App token left as empty string - Socrata allows unauthenticated throttled access"

patterns-established:
  - "City endpoint registry: static CityEndpoint.endpoints array with per-city field mappings"
  - "Density grid: 0.005-degree cells with intensity(lat:lon:) -> 0.0-1.0 normalization"
  - "GeoJSON coordinate order: coords[0]=longitude, coords[1]=latitude"
  - "Field validation before parsing: validateFields checks first JSON item for required fields"

requirements-completed: [CRIME-01, CRIME-02, CRIME-03, CRIME-04, CRIME-05, CRIME-06, CRIME-07]

# Metrics
duration: 4min
completed: 2026-03-22
---

# Phase 02 Plan 01: Real Crime Data Summary

**Multi-city CrimeService fetching real SF + Oakland incidents via Socrata SODA APIs with density grid computation, field validation, and recency labeling**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-22T19:19:29Z
- **Completed:** 2026-03-22T19:23:30Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- CityEndpoint registry with SF (wg3w-h783) and Oakland (ym6k-rx7a) SODA API configurations including field mappings and bounding boxes
- DensityGrid spatial data structure with 0.005-degree cells, intensity normalization, and factory builder from CrimeIncident arrays
- CrimeService fully rewritten: multi-city routing, parallel DispatchGroup fetches, within_circle + $limit=5000, field validation, density-normalized scoring
- All mock data code removed (loadMockData, mockIncidents) - errors surface as errorMessage instead of silent fallback

## Task Commits

Each task was committed atomically:

1. **Task 1: Create CityEndpoint and DensityGrid models** - `371e043` (feat)
2. **Task 2: Rewrite CrimeService for multi-city real data** - `b7cf09c` (feat)

## Files Created/Modified
- `HouseFriend/Models/CityEndpoint.swift` - City endpoint registry with SF and Oakland configs, bounding box matching, field mappings
- `HouseFriend/Models/DensityGrid.swift` - Spatial density grid with 0.005-degree cells, intensity lookup, factory builder
- `HouseFriend/Services/CrimeService.swift` - Multi-city real data fetching with parallel requests, field validation, density scoring

## Decisions Made
- Oakland dataset ym6k-rx7a used instead of ppgh-7dqv (confirmed no coordinate fields in ppgh-7dqv)
- Density-normalized scoring replaces old linear formula: peak cell count normalized against 50-incident baseline
- Multi-endpoint cache stores JSON with endpoint name metadata for correct re-parsing on cache hit
- Socrata app token left as empty placeholder - unauthenticated access works but is throttled
- ScoringService.crimeScore verified as pass-through - no changes needed since CrimeService now computes density score

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Xcode build with `-scheme` and `-destination 'platform=iOS Simulator,name=iPhone 17 Pro'` failed with "Supported platforms for the buildables in the current scheme is empty" - resolved by using `'generic/platform=iOS Simulator'` destination instead

## Known Stubs

1. **App token placeholder** - `HouseFriend/Services/CrimeService.swift` line ~33 - `private static let appToken = ""` - intentional per plan; Socrata allows unauthenticated access. Plan 02-01 documents this with a TODO comment. User should register at data.sfgov.org/profile/app_tokens for production use.

## User Setup Required

None - no external service configuration required for development/testing. Socrata APIs work without authentication (throttled). For production, register an app token at data.sfgov.org/profile/app_tokens.

## Next Phase Readiness
- CityEndpoint and DensityGrid models ready for Plan 02-02 (CrimeTileOverlay integration, cluster markers)
- `densityGrid` @Published property available for CrimeTileOverlay to consume
- `recencyLabel` @Published property available for neighborhood report display
- ResponseCache integration verified with multi-endpoint caching

## Self-Check: PASSED

- All 3 files verified present on disk
- Both commits (371e043, b7cf09c) verified in git log

---
*Phase: 02-real-crime-data*
*Completed: 2026-03-22*
