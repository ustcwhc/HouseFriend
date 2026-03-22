# HouseFriend

## What This Is

HouseFriend is a Bay Area "Neighborhood Health Report" iOS app that overlays 10 data layers (crime, noise, schools, earthquake, fire, electric lines, supportive housing, air quality, superfund, population) on a map to help users evaluate neighborhoods before buying or renting. It targets all 9 Bay Area counties with 445 ZIP code boundaries, long-press neighborhood scoring, and address search.

## Core Value

Users can instantly visualize and score any Bay Area neighborhood across 10 safety/quality dimensions from a single map interface — no tables, no switching apps, just tap and see.

## Requirements

### Validated

- ✓ 10-layer map overlay system (crime heatmap, noise smoke, schools, superfund, earthquake, fire hazard, electric lines, supportive housing, air quality, population) — existing
- ✓ Right-side vertical sidebar with layer toggle buttons — existing
- ✓ Top address search bar with fuzzy autocomplete (MKLocalSearchCompleter) — existing
- ✓ Long-press neighborhood report with A/B/C/D/F scoring per layer — existing
- ✓ Population layer with 445 ZIP polygons, tap-to-select, demographics sheet — existing
- ✓ Crime heatmap via MKTileOverlay with Gaussian model — existing
- ✓ Noise layer with bundled roads + Overpass detail, smoke effect rendering — existing
- ✓ ZoomTier-based annotation visibility filtering — existing
- ✓ Full 9-county Bay Area coverage — existing
- ✓ Lazy loading per layer with isLoaded flag — existing

### Active

- [ ] Real crime data integration (SF Open Data, Oakland Crime API)
- [ ] School rating data (GreatSchools API or CA School Dashboard)
- [ ] Expanded supportive housing data (SF, Oakland, Berkeley, San Mateo)
- [ ] Expanded electric lines (sub-115kV distribution lines)
- [ ] Loading spinners for all layer switches (noise done, others pending)
- [ ] Dark mode support
- [ ] Share feature (screenshot + score card image generation)
- [ ] Saved/favorited addresses
- [ ] App Store preparation (icon, screenshots, description, privacy policy)
- [ ] Neighborhood report descriptive text per layer

### Out of Scope

- Android version — iOS-first, no cross-platform for v1
- User accounts / authentication — all local, no backend
- iPad layout optimization — functional on iPad via universal build, dedicated layout deferred
- Real-time notifications — not needed for a reference/lookup app
- Social features (sharing scores, community reviews) — keep it simple for v1

## Context

- Brownfield project with all 10 data layers functional and core UI complete
- Built entirely with native Apple frameworks (SwiftUI + UIKit MapKit bridge), no third-party dependencies
- All state managed in ContentView via @State/@StateObject, no separate view model layer
- 11 ObservableObject services, one per data layer plus location
- External APIs used are all keyless (USGS, Overpass, Open-Meteo)
- Crime and school layers currently use hardcoded/estimated data — real API integration is the main data gap
- Xcode 16 with PBXFileSystemSynchronizedRootGroup (auto-adds new files)
- Bundle ID: Wancoco.HouseFriend, Apple Developer Team: T539CYBWJW

## Constraints

- **Tech stack**: Native iOS only (SwiftUI + UIKit), no third-party dependencies — maintaining zero-dependency approach
- **Platform**: iOS 17+ minimum, built with Xcode 16.4
- **Performance**: Must maintain 60fps — all computation on background threads, UI thread for rendering only
- **Data**: All external APIs must be keyless or use free tiers — no paid API subscriptions for v1
- **Thread safety**: guard value.isFinite before all Double→Int conversions; MKPolyline/MKPolygon via UIKit renderer delegate only

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| UIKit MKMapView over SwiftUI Map | SwiftUI Map cannot host MKTileOverlay or custom MKOverlayRenderer | ✓ Good |
| Zero third-party dependencies | Simplicity, no supply chain risk, App Store review speed | ✓ Good |
| All state in ContentView | Simple for current scale; may need MVVM if complexity grows | — Pending |
| Gaussian crime model as placeholder | Allows full UX without real API; replace with real data for v1.0 | — Pending |
| Bundled road data for noise | Instant load for major roads; Overpass for detail at high zoom | ✓ Good |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-22 after initialization*
