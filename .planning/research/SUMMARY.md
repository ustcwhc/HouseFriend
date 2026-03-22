# Project Research Summary

**Project:** HouseFriend — Bay Area Neighborhood Health Report iOS App
**Domain:** iOS neighborhood data app — Milestone 2 (Real Data + Polish + App Store Submission)
**Researched:** 2026-03-22
**Confidence:** MEDIUM-HIGH

## Executive Summary

HouseFriend is a mature prototype with a working 10-layer neighborhood scoring system that needs its data foundations replaced: Gaussian placeholder models swapped for real SF Open Data and California Dashboard school data, custom overlay renderers updated for dark mode, a share feature added, saved addresses persisted, and the app prepared for App Store submission. The research confirms this milestone is achievable entirely on native iOS frameworks with zero third-party dependencies, using free government open data APIs that match or exceed the quality of paid alternatives.

The recommended approach is to build in strict dependency order: first wire the `ResponseCache` caching layer, then integrate real crime and school data against it, then add dark mode renderer support, then saved addresses, then the share feature, and finally complete App Store submission assets. This ordering is driven by data dependencies — the share card is only meaningful once real data is flowing, App Store screenshots require real data in frame, and saved addresses gain value when they can capture a real score snapshot. Skipping this order would produce a visually complete but functionally hollow submission.

The biggest risks are not technical but operational: the Socrata API silently truncates results at 1,000 rows without any error signal, unauthenticated requests are throttled at shared IP pools, government dataset column names change without notice, and Apple's App Store will automatically reject submissions missing either the `PrivacyInfo.xcprivacy` manifest or a privacy policy URL accessible from within the app. Every one of these pitfalls is avoidable with a specific preventive action — registering a free app token, enforcing explicit `$limit` on every query, adding field-presence validation, and creating a hosted privacy policy page before first submission.

## Key Findings

### Recommended Stack

All features can be implemented on native Apple frameworks with no new dependencies. Crime data comes from the SF Open Data SODA API (`data.sfgov.org/resource/wg3w-h783.json`) and the Oakland CrimeWatch SODA API (`data.oaklandca.gov/resource/ppgh-7dqv.json`) — both are free, keyless (with a registered app token), and use identical Socrata query syntax. School rating data comes from the California Department of Education Dashboard, bundled at build time from annual XLSX exports rather than a live API, which avoids the $52.50+/month GreatSchools API while providing official state-authority data.

**Core technologies:**
- SF Open Data SODA API (`wg3w-h783`): real crime data — free, no auth required beyond a registered app token, 50K rows/request max
- Oakland CrimeWatch SODA API (`ppgh-7dqv`): Oakland crime data — same Socrata platform, same query syntax
- CDE Dashboard XLSX (bundled JSON): school ratings — annual download at build time, no runtime API dependency, no cost
- `overrideUserInterfaceStyle` + `MKStandardMapConfiguration`: dark mode for `MKMapView` — native iOS 13+/16+ APIs
- `UIGraphicsImageRenderer` + `drawHierarchy`: share image capture — captures live overlays, no custom overlay re-implementation needed
- `UserDefaults` + `Codable` (STACK.md recommendation) vs. SwiftData `@Model` (ARCHITECTURE.md recommendation): ARCHITECTURE.md recommends SwiftData for iOS 17+ typed persistence; STACK.md recommends `UserDefaults` for simplicity. **Resolve toward SwiftData** — the app targets iOS 17+, SwiftData provides type safety and zero manual encode/decode boilerplate, and the `UserDefaults` `PrivacyInfo.xcprivacy` declaration requirement applies regardless.
- `UIActivityViewController`: share sheet — stable iOS 6+ API, zero dependencies

**Critical version requirements:**
- Build with Xcode 16 + iOS 18 SDK (active App Store requirement since April 2025)
- Must update to Xcode 26 + iOS 26 SDK before April 28, 2026
- Age rating questionnaire in App Store Connect must be updated before January 31, 2026

### Expected Features

**Must have (table stakes):**
- Real crime data integration — app claiming to score safety with Gaussian placeholder data is not credible; every competing real estate app uses real crime feeds
- School ratings on map — Zillow, Redfin, and Homes.com all show school pins; absence reads as incomplete
- Loading spinners on all layers — missing spinner reads as app freeze; currently only the noise layer has one
- Descriptive text per layer grade — a bare "C" grade with no context is meaningless to users
- Dark mode — iOS system dark mode is a baseline expectation since iOS 13; App Store reviewers test it
- Privacy policy accessible from within the app — hard App Store rejection without it (guideline 5.1.1(i))
- App icon + App Store screenshots — cannot submit without them; screenshots require real data in frame

**Should have (competitive):**
- Shareable neighborhood score card — no competitor generates a branded composite score image; viral loop for couples comparing neighborhoods; must ship with real data, not placeholders
- Saved / favorited addresses — house hunters evaluate 3-5 neighborhoods; return visits without re-searching is table stakes for evaluation workflows

**Defer (v2+):**
- iPad-optimized split-view layout — universal build works on iPad; dedicated layout is a separate design project
- iCloud sync for saved addresses — only if users request cross-device sync post-launch
- Historical trend view — requires time-series data pipeline, not viable with current annual/daily data sources
- Additional data layers (transit, walkability, flood zones) — validate current 10 are sufficient first

### Architecture Approach

The milestone adds four orthogonal capabilities to the existing architecture — API caching, saved address persistence, dark mode for custom renderers, and screenshot/share generation — each at a different layer, each buildable independently. The existing pattern of `ContentView` owning all state and 11 `ObservableObject` services is extended with three new components: a shared `ResponseCache` (disk+memory, TTL-keyed, `NSCachesDirectory`-backed), a `FavoritesStore` (SwiftData-backed `ObservableObject` wrapper), and a `ShareService` (stateless enum-as-namespace, mirrors existing `ScoringService` pattern).

**Major components:**
1. `ResponseCache` (new, shared singleton) — two-level cache (NSCache + FileManager) with per-layer TTLs; sits inside every API service's `fetch()` call; prevents re-fetching stable government data on every map interaction
2. `FavoritesStore` (new `@StateObject` in ContentView) — SwiftData-backed list of saved addresses; converts `FavoriteAddress @Model` objects to plain `FavoriteSummary` structs before passing into `HFMapView` to keep SwiftData types out of the UIKit bridge layer
3. `ShareService` (new stateless utility) — captures live `MKMapView` via `UIGraphicsImageRenderer.drawHierarchy`, composites score card in Core Graphics, presents `UIActivityViewController`; `liveMapView` reference exposed upward from `HFMapView` via an `onMapViewReady` callback
4. Dark mode renderer refresh (modification to `HFMapView` + `Coordinator`) — `colorScheme` passed as prop into `HFMapView`, detected in `updateUIView`, triggers remove-and-re-add of all overlays to force renderer recreation with new colors

### Critical Pitfalls

1. **Socrata 1,000-row default truncation** — always pass explicit `$limit=5000` (or higher) and a `$where` spatial bounding box; never rely on the default; verify by logging returned row count for a downtown SF query and confirming it exceeds 1,000
2. **Unauthenticated Socrata throttling** — register a free app token at `data.sfgov.org/profile/app_tokens` and pass it as `X-App-Token` header on all requests; without it, shared IP pool throttling will produce intermittent 429s in TestFlight
3. **Government dataset schema changes break parsing silently** — the existing `CrimeService` silently falls back to mock data on any parse failure; add field-presence validation that surfaces a visible banner rather than silently substituting Gaussian estimates; prefer the structured `point` geo-column over flat `latitude`/`longitude` fields
4. **`MKMapSnapshotter` does not capture custom overlays** — it renders base map tiles only; using it for the share image produces a plain map with no crime heatmap, no smoke overlay, and no school pins; use `UIGraphicsImageRenderer.drawHierarchy` on the live `MKMapView` reference instead
5. **Dark mode does not automatically redraw custom `MKOverlayRenderer` subclasses** — `NoiseSmokeRenderer` and `CrimeTileOverlay` do not receive trait change callbacks because `MKOverlayRenderer` inherits from `NSObject`, not `UIView`; must explicitly call `setNeedsDisplay()` on each renderer when `hasDifferentColorAppearance` is true, and resolve colors at draw time via `UITraitCollection.current.userInterfaceStyle`, not at init time
6. **App Store rejection for missing privacy policy** — hard rejection under guideline 5.1.1(i) if the policy URL is not reachable from inside the app; the policy does not need to be complex — for a no-backend app it is a short page stating no data is collected or transmitted — but it must exist and be linked before first submission
7. **Missing or incomplete `PrivacyInfo.xcprivacy`** — mandatory since May 1, 2024; automated App Store Connect validation rejects submissions without it before reaching human review; run Xcode's Privacy Report before first archive

## Implications for Roadmap

Based on the dependency graph surfaced across all four research files, the following phase structure is recommended:

### Phase 1: API Caching Foundation
**Rationale:** Every subsequent feature (real crime data, school data, multi-city routing) depends on a stable caching layer. Building it first and testing it in isolation prevents debugging cache and API logic simultaneously later. Zero user-visible deliverable but foundational for all real data work.
**Delivers:** `ResponseCache` singleton with memory and disk layers, TTL per layer type, integration with existing `URLSession` patterns in services
**Avoids:** Pitfall — storing API responses in `UserDefaults` (loads into memory at launch, measurably slows startup)
**Research flag:** Standard pattern — well-documented NSCache + FileManager approach; no additional research needed

### Phase 2: Real Data Integration (Crime + Schools)
**Rationale:** Real data is the foundational trust signal for the entire app. The share card, App Store screenshots, and the app's core value proposition are all hollow without it. Crime data uses the Gaussian model today; school data is Swift literal stubs. Both must be replaced before any downstream feature captures or shares data.
**Delivers:** `CrimeService` and `SchoolService` wired to real SODA and CDE endpoints; school pins on map at zoom >= 13; data freshness labels in neighborhood report; crime heatmap rebuilt from real incident coordinates; multi-city routing (SF vs. Oakland endpoint selection based on pin location)
**Addresses:** Real crime data (P1), school ratings (P1), loading spinners on all layers (add as part of service wiring)
**Avoids:** Pitfalls 1 (1,000-row truncation), 2 (unauthenticated throttling), 3 (silent schema change), 8 (all traffic routing to SF endpoint regardless of pin location)
**Research flag:** Moderate — Oakland dataset field names differ from SF; validate schema at runtime against actual response before hard-coding field mappings

### Phase 3: Dark Mode Support
**Rationale:** Can be built independently of data integration but must be complete before share feature (share image should capture dark-mode-correct overlay colors) and before App Store submission (reviewers test dark mode explicitly). No data dependencies.
**Delivers:** `colorScheme` prop wired through `HFMapView`; `refreshOverlayRenderers` pattern in Coordinator; `NoiseSmokeRenderer` and `CrimeTileOverlay` using dynamic color resolution at draw time; all SwiftUI overlay views using semantic colors
**Avoids:** Pitfall 5 (custom renderers not auto-redrawing on trait change); Anti-Pattern 2 (per-render renderer recreation causing flicker)
**Research flag:** Standard pattern — `traitCollectionDidChange` and remove/re-add overlay approach is well-documented; no additional research needed

### Phase 4: Saved Addresses
**Rationale:** Independent of sharing and dark mode. Adding it after real data integration means the score snapshot captured at save time reflects real data, not placeholder grades. Low implementation cost, high frequency use case.
**Delivers:** `FavoritesStore` with SwiftData persistence; star button in neighborhood report panel; saved locations list UI; star annotation rendering on map; persistence survives app termination
**Avoids:** Anti-Pattern 1 (SwiftData types crossing the UIKit bridge — convert to plain `FavoriteSummary` struct at ContentView boundary); Pitfall — storing cache data in `UserDefaults`
**Research flag:** Standard pattern — SwiftData `@Model` + `ObservableObject` wrapper on iOS 17+ is well-documented; no additional research needed

### Phase 5: Share Feature
**Rationale:** Must come after real data (Phase 2) and dark mode (Phase 3) are stable — the share card must show real scores in correct colors. Depends on `liveMapView` reference being exposed from `HFMapView` (trivial addition). Building last avoids sharing a card that shows placeholder data or wrong-mode colors.
**Delivers:** `ShareService` with `UIGraphicsImageRenderer.drawHierarchy` capture; score card compositing via Core Graphics; `UIActivityViewController` share sheet; `NSPhotoLibraryAddUsageDescription` in Info.plist
**Avoids:** Pitfall 4 (`MKMapSnapshotter` not capturing custom overlays); Performance trap (calling `drawHierarchy` before `mapViewDidFinishRenderingMap`); `UIActivityViewController` presented off main thread
**Research flag:** Standard pattern — `drawHierarchy` + `UIActivityViewController` is well-established; no additional research needed

### Phase 6: App Store Preparation
**Rationale:** Must come after all features are implemented and real data is in place, because screenshots require real data and the privacy manifest must reflect the actual API surface of the finished app. Not a single task — several parallel tracks (icon, screenshots, policy, manifest, metadata).
**Delivers:** `PrivacyInfo.xcprivacy` with `UserDefaults` (CA92.1) and CoreLocation declarations; hosted privacy policy URL; in-app privacy policy link; 1024x1024 app icon; 6.9" and 6.5" screenshots; App Store Connect metadata (privacy nutrition labels, age rating questionnaire, export compliance); TestFlight internal beta
**Avoids:** Pitfall 6 (missing privacy policy URL — automatic rejection), Pitfall 7 (missing/incomplete privacy manifest — automated rejection before human review)
**Research flag:** Standard process — Apple's requirements are well-documented; no additional research needed. Note: age rating questionnaire deadline is January 31, 2026 — must be completed before or during this phase.

### Phase Ordering Rationale

- Phase 1 before Phase 2: caching must exist before API calls are made at volume; avoids debugging cache and API logic simultaneously
- Phase 2 before Phase 5: share card value proposition collapses if it shows placeholder grades; screenshots for App Store require real data
- Phase 3 before Phase 5: share image must capture dark-mode-correct overlay colors
- Phase 4 after Phase 2: saved score snapshots should capture real scores, not Gaussian estimates
- Phase 6 last: privacy manifest must reflect final API surface; screenshots must show real data; app icon and policy can be prepared in parallel with Phase 5 but submission only after all features are stable

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2 (Real Data Integration):** Oakland CrimeWatch dataset (`ppgh-7dqv`) field schema must be validated against a live API response before hard-coding field mappings — the schema is confirmed different from SF. Also validate that the `within_circle` geographic filter works identically on Oakland's Socrata instance.

Phases with standard patterns (skip research-phase):
- **Phase 1 (API Caching):** NSCache + FileManager two-level cache with TTL is thoroughly documented
- **Phase 3 (Dark Mode):** `traitCollectionDidChange` + remove/re-add overlay pattern has multiple high-confidence sources
- **Phase 4 (Saved Addresses):** SwiftData `@Model` on iOS 17+ is an official Apple pattern
- **Phase 5 (Share Feature):** `UIGraphicsImageRenderer.drawHierarchy` is confirmed in Apple documentation
- **Phase 6 (App Store Preparation):** Apple's submission requirements are fully documented on developer.apple.com

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Crime and school API sources verified against official portals; native iOS APIs confirmed in Apple documentation; GreatSchools pricing confirmed directly from their site |
| Features | MEDIUM-HIGH | App Store patterns HIGH confidence; responsible crime display design MEDIUM (academic and community sources, not Apple guidelines); competitor feature analysis inferred from public App Store listings |
| Architecture | HIGH | All four patterns verified against official Apple documentation or well-established community sources; SwiftData vs. UserDefaults decision has official Apple backing |
| Pitfalls | MEDIUM | Socrata row-limit and throttling behavior verified from official dev.socrata.com docs; `MKMapSnapshotter` overlay limitation verified from Apple docs and open radar; App Store rejection patterns from community sources cross-referenced with Apple guidelines |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **Oakland dataset schema:** The Oakland CrimeWatch field names (`crimetype`, `datetime`) are documented in STACK.md but marked MEDIUM confidence. Validate the actual JSON response structure against a live query before writing the parser — do not assume SF field names transfer.
- **Socrata app token for Oakland:** A separate token registration at `data.oaklandca.gov` may be required (or the SF token may work cross-instance). Verify during Phase 2.
- **`CrimeTileOverlay` tile cache on dark mode switch:** ARCHITECTURE.md notes that dark mode requires flushing the tile cache if tile colors are baked into the image data. If the heatmap uses a fixed red-to-transparent alpha-only gradient, this is a non-issue. Verify the current tile rendering approach in `CrimeTileOverlay.swift` before deciding whether a tile cache flush is needed on scheme change.
- **`drawHierarchy` timing:** The share image must be captured after `mapViewDidFinishRenderingMap` fires. The current delegate implementation status is unknown — verify whether the `Coordinator` already implements this callback or whether it needs to be added.
- **School data cross-referencing:** CDE Dashboard XLSX provides performance color but not GPS coordinates. The California Public Schools 2024-25 ArcGIS GeoJSON dataset provides coordinates. The join key is the CDS (county-district-school) code. Validate that the CDS code format matches between both datasets before building the build-time Python script.

## Sources

### Primary (HIGH confidence)
- [SF Open Data SFPD Incident Reports](https://data.sfgov.org/Public-Safety/Police-Department-Incident-Reports-2018-to-Present/wg3w-h783) — dataset ID, SODA query syntax, field names
- [Socrata SODA API Documentation](https://dev.socrata.com/consumers/getting-started.html) — row limits, pagination, app tokens, `within_circle`
- [CDE Academic Indicators Download Page](https://www.cde.ca.gov/ta/ac/cm/acaddatafiles.asp) — XLSX download URLs, annual cadence
- [California Public Schools 2024-25 dataset](https://data.ca.gov/dataset/california-public-schools-2024-25) — school location GeoJSON
- [GreatSchools NearbySchools API pricing](https://www.greatschools.org/solutions/k12-data-solutions/nearbyschools-api) — $52.50/mo confirmed, enterprise-only 1-10 ratings
- [Apple Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/) — Xcode 26 deadline, age rating deadline
- [Apple Privacy Manifest Files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) — PrivacyInfo.xcprivacy structure
- [Apple App Store Review Guidelines 5.1.1](https://developer.apple.com/app-store/review/guidelines/) — privacy policy requirements
- [Apple MKMapSnapshotter documentation](https://developer.apple.com/documentation/mapkit/mkmapsnapshotter) — custom overlay exclusion confirmed

### Secondary (MEDIUM confidence)
- [Oakland CrimeWatch API — Socrata Foundry](https://dev.socrata.com/foundry/data.oaklandca.gov/ppgh-7dqv) — dataset ID `ppgh-7dqv`, field names
- [SFPD Dataset Explainer — sfdigitalservices.gitbook.io](https://sfdigitalservices.gitbook.io/dataset-explainers/sfpd-incident-report-2018-to-present) — column schema details
- SwiftLee — Dark Mode support in UIKit: `traitCollectionDidChange`, `hasDifferentColorAppearance`
- BleepingSwift — AppStorage vs UserDefaults vs SwiftData comparison
- NSHipster — URLCache limitations without Cache-Control headers
- Apple Developer Forums — `traitCollectionDidChange` not called on coordinators
- Hacking with Swift — `UIGraphicsImageRenderer.drawHierarchy`

### Tertiary (LOW confidence)
- AIGA Eye on Design / ACM CHI — crime display ethics and individual incident dots increasing perceived danger without improving decisions (needs validation against current HouseFriend heatmap approach)
- `overrideUserInterfaceStyle` for MKMapView — pattern confirmed by community articles, not fetched from official Apple docs (JS-gated pages)
- `MKStandardMapConfiguration.preferredConfiguration` iOS 16+ — confirmed via WWDC 2022 notes and community articles

---
*Research completed: 2026-03-22*
*Ready for roadmap: yes*
