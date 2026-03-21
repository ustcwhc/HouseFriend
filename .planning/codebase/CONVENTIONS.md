# Coding Conventions

**Analysis Date:** 2026-03-21

## Naming Patterns

**Files:**
- PascalCase for all Swift files: `HFMapView.swift`, `ZoomTier.swift`, `CrimeService.swift`
- Views suffix: `DetailSheetView.swift`, `CategoryCardView.swift`, `LegendView.swift`
- Service suffix: `CrimeService.swift`, `NoiseService.swift`, `SchoolService.swift`
- Renderer suffix: `NoiseSmokeRenderer.swift`, `CrimeTileOverlay.swift`

**Types (structs, classes, enums):**
- PascalCase: `EarthquakeEvent`, `ZoomTier`, `HFAnnotation`, `NoiseRoad`
- `HF` prefix for UIKit-bridging types only: `HFMapView`, `HFAnnotation`, `HFAnnotationData`
- Codable inner types are nested inside the owning service: `EarthquakeService.USGSResponse`, `EarthquakeService.Feature`

**Functions and properties:**
- camelCase: `fetchForRegion`, `updateOverlays`, `applyZipStyle`, `loadStaticRoads`
- Boolean properties use declarative names: `showsNoiseRoads`, `showsCrimeMarkers`, `isLoading`, `isRailway`
- Factory/static methods use noun phrases: `allBayAreaSchools()`, `parseBundledJSON(_:)`, `parseOSMResponse(_:)`

**Variables:**
- camelCase throughout: `noiseRoads`, `zipRenderers`, `annotationMap`, `lastZoomTier`
- Short single-letter locals only in tight loops: `i`, `j`, `n`, `t`
- Constants use descriptive camelCase: `maxSpanForDetail`, `maxSpanForMajor`

**Enum cases:**
- camelCase: `.satellite`, `.neighborhood`, `.fireHazard`, `.milpitasOdor`
- Associated values use the model type name directly: `.school(School)`, `.earthquake(EarthquakeEvent)`

## Code Style

**Formatting:**
- No automated formatter config (no `.swiftlint.yml`, no Biome, no Prettier)
- Indentation: 4 spaces
- Opening braces on same line
- Aligned assignment columns used for visual grouping in dense initializers and switch bodies:
  ```swift
  r.fillColor   = col.withAlphaComponent(0.40)
  r.strokeColor = col.withAlphaComponent(0.70)
  r.lineWidth   = 1.5
  ```

**Linting:**
- No SwiftLint or external linter detected
- Code quality enforced via CLAUDE.md rules and code review

## Import Organization

**Order:**
1. `Foundation`
2. `SwiftUI` (views only)
3. `MapKit`
4. `CoreLocation` (when needed beyond MapKit)
5. Domain-specific Apple frameworks (e.g., `Compression`, `os`)

No path aliases — all imports are Apple system frameworks.

## Error Handling

**Network errors:** Services log via `AppLogger`, set `errorMessage: String?` on the `@Published` property, and fall back to mock/static data where available.

```swift
guard let data = data, error == nil else {
    AppLogger.network.error("Earthquake fetch failed: \(error?.localizedDescription ?? "no data")")
    DispatchQueue.main.async { self?.errorMessage = "Earthquake data unavailable" }
    return
}
```

**Parse failures:** Return `nil` from `compactMap` closures; log once at `.warning` level if the entire data set is missing.

**Geometry guards:** `guard value.isFinite` before using any computed `Double` as an `Int` or distance. Use a safe fallback:
```swift
let safeMinDist = minDist.isFinite ? minDist : 999.0
```

**UI errors:** Surfaced through `errorMessage: String?` on `@Published` — views display inline banners, not modal alerts.

## Logging

**Framework:** `os.Logger` via the `AppLogger` enum in `HouseFriend/Services/AppLogger.swift`

**Subsystems and categories:**
```swift
AppLogger.network  // URL fetches, parse results, fallbacks
AppLogger.scoring  // Score computation
AppLogger.location // GPS / CLLocation events
AppLogger.map      // Map overlay/annotation lifecycle
```

**Usage pattern:** Always use string interpolation with `\()`, matching the OSLog privacy model:
```swift
AppLogger.network.info("Noise: loaded \(parsed.count) static roads from bundle")
AppLogger.network.error("Earthquake fetch failed: \(error?.localizedDescription ?? "no data")")
```

## Comments

**When to comment:**
- MARK sections are used consistently to divide all files into named regions: `// MARK: - Overlay management`
- Inline comments explain non-obvious decisions (algorithm rationale, bug fixes tagged with ID, UIKit gotchas):
  ```swift
  // B1 fix: reset so noise rebuild works if we return
  // Ray-casting point-in-polygon (works in lon/lat space — fine for small areas)
  ```
- Doc comments (`///`) on public-facing types and non-trivial computed properties:
  ```swift
  /// Canonical zoom levels for controlling object visibility on the map.
  /// Each tier corresponds to a real-world scale and determines which objects
  /// are rendered.
  ```
- Avoid restating the code — prefer explaining "why"

## Concurrency

**Rule:** All computation off the main thread; all UI writes on main thread.

```swift
DispatchQueue.global(qos: .userInitiated).async { [weak self] in
    let parsed = Self.parseBundledJSON(data)
    DispatchQueue.main.async {
        self?.staticRoads = parsed
    }
}
```

- Network callbacks use `URLSession.shared.dataTask` with `defer { DispatchQueue.main.async { self?.isLoading = false } }` pattern
- `[weak self]` is used in all closures that capture service objects
- `Task {}` is preferred for new async/await code; `DispatchQueue.global` for existing patterns

## Function Design

**Size:** Functions with complex logic are broken into private helper methods (e.g., `updateNoisePolylines`, `applyZipStyle`, `filterRoadsToRegion`)

**Parameters:** Positional params for simple types; labeled params for coordinates and config values

**Return Values:** Prefer returning typed structs (`ScoreResult`) over tuples; `nil` via optional returns for parse failures

## Module Design

**Services:** `class` conforming to `ObservableObject` with `@Published` properties. Consumed as `@StateObject` in `ContentView`.

**Models:** Plain `struct` conforming to `Identifiable`. `id` is always a `UUID()` assigned at init, except string-keyed models (`ZIPCodeRegion` uses `String` id).

**Views:** `struct` conforming to `View` for SwiftUI; `UIViewRepresentable` for MapKit bridge. Coordinators are inner `class` types inside the representable.

**Enums for services:** Pure-static utility types use `enum` with no cases to prevent instantiation (e.g., `ScoringService`, `GeoJSONParser`).

**Barrel files:** Not used — all files imported by Xcode target membership directly.

## Zoom Tier Filtering

All annotation/overlay visibility must go through `ZoomTier` enum helpers in `HouseFriend/Models/ZoomTier.swift`. Never hardcode span thresholds in views or services:

```swift
// Correct
if tier.showsCityAnnotations { ... }
let levels = tier.schoolLevelsToShow()

// Wrong — never do this
if region.span.latitudeDelta < 0.3 { ... }
```

## Data Embedding

Never embed datasets larger than ~1K lines as Swift array literals. Use bundled JSON files loaded at runtime:
- `bayarea_zips.json` loaded by `ZIPCodeData.allZIPs()`
- `bayarea_roads.json.gz` loaded by `NoiseService.loadStaticRoads()`

School data is an exception: `SchoolService` currently embeds ~200 schools as Swift literals — this is the upper acceptable limit.

---

*Convention analysis: 2026-03-21*
