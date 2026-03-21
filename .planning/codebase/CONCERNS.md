# Codebase Concerns

**Analysis Date:** 2026-03-21

---

## Tech Debt

**ContentView.swift is a 1,282-line monolithic view:**
- Issue: All UI state, map callbacks, scoring logic, search logic, and detail sections live in one file. The view body alone has nested `ZStack` layers, 10 `@StateObject` properties, and inline `@ViewBuilder` sections for every category type.
- Files: `HouseFriend/ContentView.swift`
- Impact: Hard to test individual UI sections, slow SwiftUI preview recompilation, high cognitive load for any change. Any new data layer requires editing in multiple places in this file.
- Fix approach: Extract `BottomPanel`, `SearchBar`, `SideBar`, and `CategoryDetailSection` into separate view files. Move `computeScores`, `loadLayerIfNeeded`, `loadAllData` into a `ViewModel` or coordinator.

**Crime data is entirely fake (Gaussian model, not real incidents):**
- Issue: `CrimeTileOverlay.crimeValue()` uses 21 hardcoded hotspot coordinates with Gaussian decay — it is a statistical approximation, not real crime data. The "Details" mode (`refreshCrimeIncidents()`) generates random incident markers using the same model with `Double.random()`.
- Files: `HouseFriend/Views/CrimeTileOverlay.swift` lines 76–107, `HouseFriend/ContentView.swift` lines 853–879
- Impact: Crime scores and heatmap have no relationship to actual police records. Displayed scores are plausible-looking fiction. Users making housing decisions may be misled.
- Fix approach: Integrate a real crime data source (SF Open Data `wg3w-h783`, Oakland Crime Watch, SFPD GeoJSON). The `CrimeService.fetchNear()` already attempts SF Open Data but falls back to mock data; the tile overlay model needs to be replaced entirely with real spatial data.

**School ratings are hardcoded static data:**
- Issue: 130+ schools in `SchoolService` have manually assigned `rating` values (1–10) that are not sourced from any live API or verifiable dataset. Ratings were set by the developer and will drift from reality over time.
- Files: `HouseFriend/HouseFriend/Services/SchoolService.swift` lines 38–215
- Impact: School scores in the Neighborhood Report are inaccurate and will not reflect school performance changes, openings, or closures.
- Fix approach: Replace with GreatSchools API, CA Department of Education data, or Niche.com API. At minimum, document the data source year in code comments.

**Fire hazard zones are hardcoded (22 zones):**
- Issue: `FireDataService` contains 22 hardcoded `FireHazardZone` polygon entries. These are not fetched from CAL FIRE's actual GIS service.
- Files: `HouseFriend/HouseFriend/Services/FireDataService.swift`
- Impact: Zone boundaries and severity ratings will not update when CAL FIRE updates FHSZ maps (last major update was 2021–2022). Newly designated zones will be missed.
- Fix approach: Fetch from CAL FIRE's FHSZ REST API or bundle updated GeoJSON from their public data portal.

**Electric line corridors are hardcoded:**
- Issue: `ElectricLinesService` contains a static list of PG&E transmission corridors defined as coordinate arrays with estimated voltage values.
- Files: `HouseFriend/HouseFriend/Services/ElectricLinesService.swift`
- Impact: Cannot reflect new transmission infrastructure or decommissioned lines.
- Fix approach: Use PG&E's publicly available GIS data or OpenStreetMap power line tags.

**Superfund sites are hardcoded (62 sites):**
- Issue: `SuperfundService` has 62 hardcoded EPA NPL site entries.
- Files: `HouseFriend/HouseFriend/Services/SuperfundService.swift`
- Impact: New listings or deletions from the EPA NPL are not reflected.
- Fix approach: EPA's EJSCREEN or Superfund REST API provides queryable NPL site data.

**Supportive housing data is sparse:**
- Issue: `SupportiveHousingService` has acknowledged gaps in SF, Oakland, and Berkeley coverage (per KNOWN_ISSUES.md).
- Files: `HouseFriend/HouseFriend/Services/SupportiveHousingService.swift`
- Impact: The "Supportive Housing" layer shows incomplete data in the three highest-density urban areas — exactly where it matters most.
- Fix approach: Import full facility lists from SF DPH, Oakland city open data, or HUD's LIHTC database.

**`computeScores()` uses a 1.8-second fixed delay instead of reactive updates:**
- Issue: In `ContentView.computeScores()`, all scores are computed inside a `DispatchQueue.main.asyncAfter(deadline: .now() + 1.8)` block. This delay is a workaround to wait for async network calls to complete — the actual data readiness is not coordinated.
- Files: `HouseFriend/ContentView.swift` lines 966–999
- Impact: On slow networks, scores will compute before data has arrived and show stale/fallback values. On fast devices, the 1.8-second wait is unnecessary UX delay.
- Fix approach: Use `async/await` with `withTaskGroup` to await all service fetches, then compute scores reactively on completion.

**`odorMapZones()` is a plain function in ContentView returning hardcoded coordinate arrays:**
- Issue: The Milpitas Odor layer zones are defined as inline `CLLocationCoordinate2D` literals inside a function in `ContentView.swift` (lines 1023–1098), mixed with UI code.
- Files: `HouseFriend/ContentView.swift` lines 1023–1098
- Impact: Data and view are tightly coupled, making the odor layer impossible to test in isolation.
- Fix approach: Move to a dedicated `OdorZoneService` similar to other data services.

---

## Known Bugs

**Overpass API times out on Mac (simulator testing):**
- Symptoms: Noise layer shows spinner indefinitely; static roads appear but detail never loads.
- Files: `HouseFriend/HouseFriend/Services/NoiseService.swift` lines 220–283
- Trigger: Running in iOS Simulator on Mac when network routing for Overpass API returns 504.
- Workaround: Test noise layer on a physical iOS device. Two mirror URLs are tried before falling back to static data. This is documented in KNOWN_ISSUES.md.

**Crime score always uses SF Open Data regardless of location:**
- Symptoms: `CrimeService.fetchNear()` always queries the SF Open Data endpoint (`data.sfgov.org`) even when the pinned location is in Oakland, San Jose, or other cities outside SF.
- Files: `HouseFriend/HouseFriend/Services/CrimeService.swift` lines 25–63
- Trigger: Any long-press or search outside San Francisco.
- Workaround: The tile overlay uses the Gaussian model which is location-aware; the incident fetch falls back to mock data for non-SF locations.

**`CrimeIncident.date` is always `Date()` (now), not the actual incident date:**
- Symptoms: All crime incidents shown in Details mode show the current date instead of actual incident dates.
- Files: `HouseFriend/HouseFriend/Services/CrimeService.swift` line 52
- Trigger: Whenever crime detail markers are displayed.

**First-location fly-to check uses hardcoded coordinate equality:**
- Symptoms: The fly-to-user-location guard `guard let loc, currentCenter.latitude == 37.450` prevents flying to user location if the user has moved the map before location permission is granted.
- Files: `HouseFriend/ContentView.swift` line 215
- Trigger: User moves map before location permission is granted, then grants permission.

---

## Security Considerations

**No API key management needed (current state):**
- Risk: Open-Meteo and USGS are keyless public APIs. SF Open Data is also keyless. No secrets are currently embedded in the codebase.
- Files: N/A
- Current mitigation: Architecture intentionally avoids paid/keyed APIs.
- Recommendations: If a paid data source is added (GreatSchools, PG&E GIS, etc.), use iOS Keychain or server-side proxy rather than embedding keys in the bundle.

**SF Open Data endpoint is unauthenticated with no rate limiting in client:**
- Risk: The app makes SF Open Data requests without any rate limiting or throttling on the client side. Heavy use or a loop bug could get the device IP rate-limited by Socrata.
- Files: `HouseFriend/HouseFriend/Services/CrimeService.swift` lines 29–63
- Current mitigation: Only called on location pin or search, not on a timer.
- Recommendations: Add a minimum interval between requests (similar to the Overpass debounce pattern in `NoiseService`).

---

## Performance Bottlenecks

**CrimeTileOverlay renders O(size²) pixels synchronously per tile:**
- Problem: `CrimeTileOverlay.renderTile()` loops over every pixel in a tile (up to 128×128 = 16,384 pixels at zoom 14+), calling `crimeValue()` per pixel. `crimeValue()` iterates over 21 hotspots and 11 safe zones per call — ~33 iterations per pixel. At zoom 14, a full screen loads 6–12 tiles = ~1.2–2.4 million `crimeValue()` calls.
- Files: `HouseFriend/HouseFriend/Views/CrimeTileOverlay.swift` lines 38–57
- Cause: No vectorized computation, no spatial index, per-pixel function call overhead.
- Improvement path: Pre-bake the heatmap to PNG tiles at build time; or use Metal/Accelerate for SIMD computation; or reduce resolution at lower zoom levels (already partially done with 64px at z<11).

**Noise layer renders all roads in one batch on camera change:**
- Problem: Every camera pan on the noise layer rebuilds the entire `noisePolylines` array by removing all overlays and re-adding them. With 15K+ static roads + Overpass detail, this can add thousands of `MKPolyline` objects per pan.
- Files: `HouseFriend/HouseFriend/Views/HFMapView.swift` lines 189–210
- Cause: Hash-based change detection only prevents redundant updates when `roads` array is identical. Any Overpass refresh rebuilds all overlays.
- Improvement path: Use a viewport-based tile system for noise roads; only add/remove roads entering/leaving the viewport instead of full replacement.

**`updateAnnotations()` runs a full linear scan of all annotations on every zoom tier change:**
- Problem: `HFMapView.updateAnnotations()` iterates over all schools, superfund sites, earthquake events, etc. on every `regionDidChangeAnimated` where the zoom tier changes.
- Files: `HouseFriend/HouseFriend/Views/HFMapView.swift` lines 214–285
- Cause: No spatial index; uses linear `for` loops over full datasets.
- Improvement path: Pre-bucket annotations by zoom tier at load time to make tier switching O(1) lookup.

**`handleTap` checks all annotations with `map.annotations.contains` on every tap:**
- Problem: In `Coordinator.handleTap()`, the hit-test for annotation views iterates `map.annotations` — which includes all currently visible annotations — for every tap event.
- Files: `HouseFriend/HouseFriend/Views/HFMapView.swift` lines 494–498
- Cause: No spatial index for tap hit-testing.
- Improvement path: Let MapKit's native `mapView(_:didSelect:)` handle annotation taps; remove the manual annotation hit-test in `handleTap`.

---

## Fragile Areas

**Noise road overlay hash uses only first/last `wayId`:**
- Files: `HouseFriend/HouseFriend/Views/HFMapView.swift` lines 192–196
- Why fragile: The hash for detecting road list changes uses `roads.count + first.wayId + last.wayId`. Two different road lists with the same count and same first/last IDs (but different middle roads) will be treated as identical, preventing an overlay refresh.
- Safe modification: Replace with a proper content hash over all wayIds, or use a monotonically increasing version counter in `NoiseService`.
- Test coverage: No unit test covers this hash logic.

**`suppressRegionCallback` uses a 0.5-second `asyncAfter` timer:**
- Files: `HouseFriend/HouseFriend/Views/HFMapView.swift` lines 110–115
- Why fragile: The 0.5s duration is arbitrary. If `setRegion(animated: true)` takes longer (e.g., on slow devices or large region jumps), `suppressRegionCallback` resets too early and triggers spurious camera change callbacks, which can re-trigger `noiseService.fetchForRegion`.
- Safe modification: Use `mapViewDidFinishRenderingMap` or `regionDidChangeAnimated` to detect completion instead of a fixed timer.

**ZIP polygon hit test (`coordinateInsidePolygon`) runs in lat/lon space:**
- Files: `HouseFriend/HouseFriend/Views/HFMapView.swift` lines 526–542
- Why fragile: The ray-casting algorithm operates directly on latitude/longitude without accounting for Mercator projection distortion. Near the poles this would fail; for Bay Area latitudes (37–38°N) the error is small but measurable for narrow ZIP shapes.
- Safe modification: Convert to MKMapPoint (projected) space before ray-casting for accuracy. This is noted as a known approximation in the code comment.
- Test coverage: No geographic unit test for edge-case ZIPs.

**`GeoJSONParser.swift` has no error reporting path:**
- Files: `HouseFriend/HouseFriend/GeoJSONParser.swift`
- Why fragile: Parse failures return empty arrays silently. A corrupted `bayarea_zips.json` would result in an empty ZIP layer with no user-visible error.
- Safe modification: Return a `Result<[T], Error>` or `throw` on parse failure; propagate to the UI error banner.

**`NoiseService.gunzip()` assumes fixed 8 MB output buffer:**
- Files: `HouseFriend/HouseFriend/Services/NoiseService.swift` lines 368–403
- Why fragile: The gzip decompressor pre-allocates exactly 8 MB. If the decompressed road data ever exceeds 8 MB (e.g., after a data refresh with more roads), `compression_decode_buffer` will silently truncate the output and `decoded > 0` will still pass — returning a partial road dataset without error.
- Safe modification: Check `decoded == bufferSize` as a signal of truncation and either retry with a larger buffer or log a warning.

---

## Scaling Limits

**Bay Area only — no geographic generalization:**
- Current capacity: All data layers (crime hotspots, fire zones, electric lines, schools, Superfund sites, odor zones, population data) are hardcoded to Bay Area coordinates.
- Limit: The app cannot be used for any other metro area without replacing every data source.
- Scaling path: Parametrize data sources by bounding box; replace hardcoded datasets with API-driven or GeoJSON-bundled data per region.

**445 ZIP polygons always loaded and rendered (no viewport culling at model level):**
- Current capacity: All 445 ZIPs from `bayarea_zips.json` (693 KB) are loaded into `@State var zipRegions` at app launch and passed into `HFMapView` on every render.
- Limit: MapKit handles viewport culling at the overlay level, but passing all 445 polygons as props on every SwiftUI update is O(n) work. At significantly higher polygon counts this would degrade.
- Scaling path: Filter `zipRegions` to visible viewport before passing to `HFMapView`.

---

## Dependencies at Risk

**Overpass API (free, community-run):**
- Risk: The noise layer's detail data depends on two community-run Overpass API mirrors (`overpass-api.de`, `overpass.kumi.systems`). Both are funded by donations and have no SLA. The Mac/simulator timeout issue (KNOWN_ISSUES R001) already demonstrates reliability problems.
- Impact: Noise detail layer degrades to static bundle (major roads only) when Overpass is unavailable.
- Migration plan: Add a third mirror; or replace with a self-hosted Overpass instance; or pre-generate and bundle neighborhood-level road data.

**Open-Meteo Air Quality API (free, no key):**
- Risk: Free tier, no formal SLA. Currently the only source of real-time AQI data.
- Impact: AQI falls back to hardcoded `aqi: 52` ("Moderate") on failure — every location shows the same fallback score.
- Migration plan: Add AirNow API (EPA, free with key) as a secondary source.

**USGS Earthquake API:**
- Risk: Government API, generally reliable but has had planned maintenance outages.
- Impact: Earthquake layer shows empty state with error banner on failure.
- Migration plan: Cache last successful response to disk (UserDefaults or file) with a TTL; show stale data during outages.

---

## Missing Critical Features

**No data freshness indicators:**
- Problem: The app shows school ratings, fire zones, Superfund sites, and electric line data with no indication of when it was last updated or how old it is. School rating "10" could be from any year.
- Blocks: User trust and accuracy disclosure.

**Crime score does not vary by location outside SF:**
- Problem: The `CrimeService` always queries SF Open Data. Outside SF, it always falls back to the Gaussian mock model, making crime scores for Oakland, San Jose, etc. statistically modeled rather than data-driven.
- Blocks: Accurate neighborhood reporting for the majority of Bay Area geography.

**No offline mode / caching:**
- Problem: Network-dependent layers (earthquake, air quality, noise detail) show loading states or error banners with no persistence of previously fetched data. Reopening the app requires re-fetching everything.
- Blocks: Usability in low-connectivity environments (open houses, basements).

---

## Test Coverage Gaps

**`ContentView` has zero unit or integration tests:**
- What's not tested: Score computation flow with the 1.8s delay, layer switching behavior, ZIP tap and highlight lifecycle, long-press pin drop, search and resolve flow.
- Files: `HouseFriend/ContentView.swift`
- Risk: Regressions in core user flows go undetected until manual QA.
- Priority: High

**`CrimeTileOverlay` render pipeline is untested:**
- What's not tested: `renderTile()`, `crimeValue()` boundary conditions, `crimeRGB()` color thresholds, tile bounds math.
- Files: `HouseFriend/HouseFriend/Views/CrimeTileOverlay.swift`
- Risk: Off-by-one in tile coordinate math, unexpected NaN from `crimeValue`, or incorrect color thresholding would be invisible until visual inspection.
- Priority: Medium

**`NoiseService` parser and gzip decompressor are untested:**
- What's not tested: `parseBundledJSON()` with malformed input, `parseOSMResponse()` with missing node IDs, `gunzip()` with truncated input or wrong header flags.
- Files: `HouseFriend/HouseFriend/Services/NoiseService.swift`
- Risk: A corrupted bundle or unexpected Overpass response format would produce an empty noise layer with no error logged.
- Priority: Medium

**UI tests are empty stubs:**
- What's not tested: Layer switching, search interaction, ZIP tap, long-press report, bottom panel display.
- Files: `HouseFriendUITests/HouseFriendUITests.swift`
- Risk: No automated regression coverage for any user-facing interaction.
- Priority: High

**`HFMapView` coordinator logic is untested:**
- What's not tested: Overlay diffing, annotation diff logic, ZIP highlight update, noise hash change detection, tap gesture hit testing.
- Files: `HouseFriend/HouseFriend/Views/HFMapView.swift`
- Risk: The coordinator is the most complex class in the codebase and has the fragile hash logic described above. Bugs introduced here affect all 10 layers.
- Priority: High

---

*Concerns audit: 2026-03-21*
