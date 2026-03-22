# Architecture Patterns

**Domain:** iOS neighborhood data app — SwiftUI + UIKit MapKit hybrid
**Researched:** 2026-03-22
**Overall confidence:** HIGH (all patterns verified against official Apple docs or well-established iOS community sources)

---

## Context: What This Milestone Adds

The existing architecture is a single-screen SwiftUI app with:
- `ContentView` owning all state as `@State` / `@StateObject`
- 11 `ObservableObject` services, one per data layer
- `HFMapView` as a `UIViewRepresentable` bridging to `MKMapView`
- `HFMapView.Coordinator` implementing `MKMapViewDelegate`
- Custom `NoiseSmokeRenderer: MKOverlayRenderer` and `CrimeTileOverlay: MKTileOverlay`
- Zero third-party dependencies

The milestone adds four orthogonal capabilities: **API caching**, **saved addresses persistence**, **dark mode for custom renderers**, and **screenshot/share generation**. Each integrates at a different layer and can be built independently.

---

## Recommended Architecture

### Overall Integration Map

```
HouseFriendApp
└── ContentView (@State + @StateObject)
    ├── [Services Layer]  ← API caching added here
    │   ├── CrimeService, SchoolService, ...
    │   └── [NEW] ResponseCache (shared utility)
    ├── [Persistence Layer]  ← saved addresses added here (new)
    │   └── [NEW] FavoritesStore (ObservableObject, SwiftData-backed)
    ├── HFMapView (UIViewRepresentable)
    │   └── Coordinator (MKMapViewDelegate)
    │       ├── NoiseSmokeRenderer  ← dark mode handling here
    │       └── CrimeTileOverlay    ← dark mode handling here
    └── [Share Layer]  ← screenshot generation added here (new)
        └── [NEW] ShareService (stateless, async)
```

---

## Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `ResponseCache` | TTL-keyed disk+memory response cache, shared by all services | All API-calling services |
| `FavoritesStore` | SwiftData-backed list of saved addresses; `ObservableObject` wrapper | `ContentView`, `HFMapView` (annotation display) |
| `ShareService` | Capture current map view as `UIImage`, composite score card, present `UIActivityViewController` | `ContentView` (initiates), `HFMapView.Coordinator` (renders) |
| `NoiseSmokeRenderer` | Custom polyline smoke drawing with dark-mode-aware colors | `HFMapView.Coordinator.mapView(_:rendererFor:)` |
| `CrimeTileOverlay` | Gaussian heatmap tiles with dark-mode-aware palette | `HFMapView.Coordinator.mapView(_:rendererFor:)` |

---

## Pattern 1: API Response Caching

### What

A shared `ResponseCache` utility sits between `URLSession` and service `fetch()` calls. It stores raw `Data` responses keyed by URL string with a configurable TTL.

### Why this approach

`URLCache` (HTTP-layer caching) only works when servers return proper `Cache-Control` headers. Open Data APIs (SF Open Data, Oakland Crime, CA School Dashboard) do not reliably include these headers. A manual two-level cache — `NSCache` for in-memory hot reads, `FileManager`+`JSONEncoder` for cross-launch disk persistence — gives explicit TTL control without depending on server behavior.

**Confidence:** HIGH — pattern verified against Swift by Sundell's caching article and NSHipster's URLCache guide.

### Data Flow

```
service.fetch()
  └── ResponseCache.get(url:)
        ├── hit (< TTL): return cached Data → decode → publish
        └── miss: URLSession.dataTask → store in cache → decode → publish
```

### Structure

```swift
// HouseFriend/Services/ResponseCache.swift
final class ResponseCache {
    static let shared = ResponseCache()

    // L1: in-memory, process-lifetime
    private let memCache = NSCache<NSString, NSData>()

    // L2: disk, persists across launches
    private let cacheDir: URL   // FileManager.default.urls(for: .cachesDirectory)

    struct Entry: Codable {
        let data: Data
        let storedAt: Date
    }

    // TTL per data type: crime 24h, school 7d, housing 30d
    func get(key: String, ttl: TimeInterval) -> Data?
    func store(key: String, data: Data)
    func invalidate(key: String)
}
```

### Integration Point

Each service calls `ResponseCache.shared.get(key: url, ttl: layerTTL)` before creating a `URLSessionDataTask`. If hit, decode and publish immediately on the calling (background) thread; if miss, fetch then store.

Do not change the existing service `@Published` / `DispatchQueue.main.async` publish pattern — caching is purely an insertion point inside `fetch()`.

**Recommended TTLs:**
- Crime incidents: 24 hours (daily update cadence on SF Open Data)
- School ratings: 7 days (CA Dashboard updates quarterly)
- Supportive housing: 30 days (slow-moving dataset)

---

## Pattern 2: Saved Addresses Persistence

### What

A `FavoritesStore: ObservableObject` holds a SwiftData-backed list of saved addresses. Users can save/unsave any long-pressed or searched address.

### Why SwiftData over UserDefaults+JSON

For 10–20 saved addresses with typed fields (name, lat, lon, score snapshot), SwiftData is the right tool on iOS 17+:
- `@AppStorage` + JSON encoding works but loses type safety and is verbose for structured data
- `UserDefaults` loads the entire plist into memory at launch — fine for <100 items, but still requires manual `Codable` boilerplate
- SwiftData provides querying, sorting, and a clean `@Model` macro with zero manual encode/decode

The app already requires iOS 17+, so SwiftData is available.

**Confidence:** HIGH — confirmed by Apple's SwiftData documentation and the BleepingSwift AppStorage vs SwiftData comparison.

### Model

```swift
// HouseFriend/Models/FavoriteAddress.swift
import SwiftData

@Model
final class FavoriteAddress {
    var id: UUID
    var displayName: String       // "123 Main St, San Francisco"
    var latitude: Double
    var longitude: Double
    var savedAt: Date
    var scoreSnapshot: [String: Int]?   // layer → score at time of save (optional)

    init(displayName: String, latitude: Double, longitude: Double) {
        self.id = UUID()
        self.displayName = displayName
        self.latitude = latitude
        self.longitude = longitude
        self.savedAt = Date()
    }
}
```

### Store Wrapper

```swift
// HouseFriend/Services/FavoritesStore.swift
@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var favorites: [FavoriteAddress] = []

    private let modelContainer: ModelContainer
    private var modelContext: ModelContext

    init() {
        // Initialized once in ContentView as @StateObject
        let schema = Schema([FavoriteAddress.self])
        modelContainer = try! ModelContainer(for: schema)
        modelContext = modelContainer.mainContext
        loadAll()
    }

    func save(_ address: FavoriteAddress) { ... }
    func remove(_ address: FavoriteAddress) { ... }
    func isFavorite(latitude: Double, longitude: Double) -> Bool { ... }
}
```

### Integration Point in ContentView

```swift
// ContentView.swift — add alongside existing @StateObject declarations
@StateObject private var favoritesStore = FavoritesStore()
```

The `favoritesStore.favorites` array passes down to `HFMapView` as a value-type prop (converted to a simple struct for the bridge), enabling star-annotation rendering on saved locations alongside existing `HFAnnotation` types.

**Important:** Do not add `FavoriteAddress` to `HFAnnotationData` directly — keep SwiftData types out of the UIKit layer. Convert to a plain `FavoriteSummary` struct at the `ContentView` boundary.

---

## Pattern 3: Dark Mode for Custom Renderers

### The Core Problem

`MKMapView` automatically adapts its base tiles to light/dark mode. Custom `MKOverlayRenderer` subclasses (`NoiseSmokeRenderer`, `CrimeTileOverlay`) do NOT adapt automatically — they use hardcoded colors. When the system switches to dark mode, these overlays appear jarring against the now-dark map tiles.

**Confidence:** HIGH — confirmed by UIKit documentation on `traitCollectionDidChange` and MapKit overlay rendering patterns.

### How Trait Changes Reach the Coordinator

The `HFMapView.Coordinator` is not a `UIView` or `UIViewController`, so it does not directly receive `traitCollectionDidChange`. The `MKMapView` UIView does receive it. The bridge is:

1. Override `updateUIView` in `HFMapView` (called on every SwiftUI re-render)
2. Or: pass a `colorScheme` binding through `HFMapView` and detect changes

The cleanest approach for this codebase (all state in ContentView) is to **pass `colorScheme` as a prop into `HFMapView`** and detect changes in `updateUIView`:

```swift
// HFMapView.swift
struct HFMapView: UIViewRepresentable {
    // ... existing props ...
    let colorScheme: ColorScheme    // add this

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // detect scheme change
        if context.coordinator.lastColorScheme != colorScheme {
            context.coordinator.lastColorScheme = colorScheme
            context.coordinator.refreshOverlayRenderers(mapView)
        }
        // ... existing overlay/annotation update logic ...
    }
}

// ContentView.swift
@Environment(\.colorScheme) private var colorScheme
// Pass into HFMapView(..., colorScheme: colorScheme)
```

### Renderer Refresh Pattern

MapKit does not expose a public API to force-recreate a renderer for an existing overlay. The only reliable pattern is: **remove overlay from map, re-add it**. This triggers `mapView(_:rendererFor:)` again with a freshly instantiated renderer.

```swift
// HFMapView.Coordinator
func refreshOverlayRenderers(_ mapView: MKMapView) {
    // Snapshot current overlays
    let current = mapView.overlays
    mapView.removeOverlays(current)
    mapView.addOverlays(current)
    // MKMapViewDelegate.mapView(_:rendererFor:) fires for each; renderers
    // are recreated and now read the current colorScheme from the coordinator
}
```

### Renderer Color Design

Renderers must not embed hardcoded `UIColor` literals. Instead, accept a `isDarkMode: Bool` at creation time or check `UITraitCollection.current.userInterfaceStyle`:

```swift
// NoiseSmokeRenderer
init(overlay: MKOverlay, isDark: Bool) {
    self.smokeColor = isDark
        ? UIColor(white: 0.9, alpha: 0.18)
        : UIColor(white: 0.2, alpha: 0.18)
    super.init(overlay: overlay)
}
```

`CrimeTileOverlay` (which renders its own tiles via Core Graphics) reads `isDark` from a stored property set at init time. Since tiles are cached in `URLCache`, a dark-mode switch must also flush the tile cache to force redraw at new colors — or the tile rendering must be color-agnostic (e.g., using an alpha-only heatmap composited on the map) to avoid invalidation entirely.

**Recommended approach for CrimeTileOverlay:** Make the Gaussian heatmap tiles use a fixed red-to-transparent gradient regardless of mode (already visible on both light and dark base maps). Only `NoiseSmokeRenderer` needs the full scheme-aware color switch.

---

## Pattern 4: Screenshot / Share Generation

### Two Valid Approaches

| Approach | Captures custom overlays? | Captures current zoom/region? | Complexity |
|----------|--------------------------|-------------------------------|------------|
| `UIGraphicsImageRenderer` + `drawHierarchy` on the live `MKMapView` | YES — draws whatever is on screen | YES | Low |
| `MKMapSnapshotter` + manual composite | NO (manual composite required) | Configurable | High |

**Recommendation: Use `UIGraphicsImageRenderer.drawHierarchy` on the live `MKMapView`.**

`MKMapSnapshotter` does NOT capture custom `MKOverlayRenderer` output automatically. Manually compositing `NoiseSmokeRenderer` and `CrimeTileOverlay` onto a snapshot image requires re-implementing the full rendering pipeline — significant complexity for no user benefit. Capturing the live map view is simpler, captures exactly what the user sees, and requires no redraw.

**Confidence:** HIGH — Apple documentation confirms `MKMapSnapshotter` does not include custom overlays; `drawHierarchy` is the standard pattern confirmed in multiple developer community sources.

### Data Flow

```
User taps "Share" button
  └── ContentView calls ShareService.share(mapView:scores:address:from:)
        ├── Capture live map: UIGraphicsImageRenderer.drawHierarchy(mapView)
        ├── Compose score card overlay (CoreGraphics text + colored blocks)
        ├── Merge into final UIImage
        └── Present UIActivityViewController from the given sourceView
```

### Structure

```swift
// HouseFriend/Services/ShareService.swift
enum ShareService {
    // Pure function: takes a UIView snapshot + score data, returns UIImage
    static func buildShareImage(
        mapSnapshot: UIImage,
        address: String,
        scores: [CategoryScore]
    ) -> UIImage

    // Presents share sheet; must run on main thread
    @MainActor
    static func present(
        mapView: MKMapView,
        address: String,
        scores: [CategoryScore],
        from sourceView: UIView
    )
}
```

`buildShareImage` uses `UIGraphicsImageRenderer` to composite:
1. The map snapshot as background
2. A semi-transparent score card rectangle drawn in Core Graphics
3. Address text and per-layer score labels via `NSAttributedString` drawing

This keeps `ShareService` as a stateless utility (matching the `ScoringService` enum-as-namespace pattern already in the codebase) with no stored state.

### Accessing the Live MKMapView from ContentView

`HFMapView` is a `UIViewRepresentable`. The underlying `MKMapView` is not directly accessible from SwiftUI. The cleanest zero-dependency approach:

Add a binding or callback to `HFMapView` that exposes the live `UIView` reference upward:

```swift
// HFMapView.swift
struct HFMapView: UIViewRepresentable {
    var onMapViewReady: ((MKMapView) -> Void)?   // called once in makeUIView

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        // ... setup ...
        onMapViewReady?(map)
        return map
    }
}

// ContentView.swift
@State private var liveMapView: MKMapView?

HFMapView(
    ...,
    onMapViewReady: { self.liveMapView = $0 }
)
```

The `liveMapView` reference is then passed to `ShareService.present(mapView:...)`.

**Thread note:** `drawHierarchy(in:afterScreenUpdates:true)` must be called on the main thread. `ShareService.present` is marked `@MainActor` to enforce this.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: SwiftData types crossing the UIKit bridge

**What:** Passing `@Model` `FavoriteAddress` objects into `HFMapView` directly.
**Why bad:** SwiftData `@Model` objects are Observable (not ObservableObject); they carry SwiftData context references. Passing them through `UIViewRepresentable` props causes unexpected retain cycles and violates the architectural boundary.
**Instead:** Convert to a plain `FavoriteSummary` struct (`id: UUID, lat: Double, lon: Double`) at the `ContentView` boundary before passing into `HFMapView`.

### Anti-Pattern 2: Per-render renderer recreation

**What:** Calling `refreshOverlayRenderers` on every `updateUIView` call (not just on scheme changes).
**Why bad:** `updateUIView` fires on every SwiftUI state change. Removing and re-adding all overlays on each render causes visible flicker and defeats the annotation diffing logic already in the codebase.
**Instead:** Gate renderer refresh on `lastColorScheme != newColorScheme` (see Pattern 3).

### Anti-Pattern 3: MKMapSnapshotter for share images

**What:** Using `MKMapSnapshotter` to generate the share image.
**Why bad:** Does not include `NoiseSmokeRenderer` or `CrimeTileOverlay` output. Requires full re-implementation of overlay rendering in a separate Core Graphics context. The share image would not match what the user sees.
**Instead:** `UIGraphicsImageRenderer.drawHierarchy` on the live `MKMapView` reference.

### Anti-Pattern 4: Storing ResponseCache entries in UserDefaults

**What:** Using `UserDefaults` as the disk layer for API response cache.
**Why bad:** UserDefaults loads all values into memory at launch. API responses (GeoJSON, CSV) can be hundreds of KB each; storing even 3–4 layers' worth will measurably slow app startup.
**Instead:** `FileManager` writes to `NSCachesDirectory` — iOS manages eviction, excluded from backups, appropriate for reconstructible data.

---

## Suggested Build Order

This ordering is driven by dependencies between features, not feature priority:

1. **ResponseCache utility** — no dependencies; enables all real API integrations; foundational for the milestone. Build and test before wiring services.

2. **Real API service integrations** — wire `CrimeService` and `SchoolService` to real endpoints using `ResponseCache`. Validates that the cache layer works end-to-end. Other services follow the same pattern.

3. **Dark mode renderer support** — no dependencies on persistence or sharing; can be built independently. Add `colorScheme` prop to `HFMapView`, implement renderer refresh. Test in simulator with appearance toggle.

4. **FavoritesStore + saved addresses UI** — depends on the `@StateObject` pattern already established. Add after core data layers are working so the save action can capture real scores.

5. **Share feature** — depends on `liveMapView` reference (trivial to add) and the existing score/address state in `ContentView`. Build last because it composes map rendering + scores into a single feature; both must be stable first.

---

## Data Flow: New Features Integrated with Existing Pattern

### Cached API Fetch (CrimeService example)

```
loadLayerIfNeeded(.crime)
  └── CrimeService.fetch()
        └── ResponseCache.get(key: sfOpenDataURL, ttl: 86400)
              ├── cache hit  → decode JSON → crimeMarkers[@Published] → ContentView re-render
              └── cache miss → URLSession → store in cache → decode → publish
```

### Save Address

```
User taps ★ on neighborhood report panel
  └── ContentView: favoritesStore.save(FavoriteAddress(from: pinnedAddress, scores: categories))
        └── SwiftData insert → persists to SQLite in app container
              └── favoritesStore.favorites[@Published] updates
                    └── ContentView passes [FavoriteSummary] into HFMapView
                          └── Coordinator.updateAnnotations: star annotation added to map
```

### Share

```
User taps share button
  └── ContentView: ShareService.present(mapView: liveMapView!, address: pinnedAddress, scores: categories, from: shareButton)
        ├── UIGraphicsImageRenderer captures live MKMapView (main thread)
        ├── buildShareImage composites score card
        └── UIActivityViewController presented from shareButton
```

### Dark Mode Switch

```
System appearance changes → SwiftUI environment colorScheme updates
  └── ContentView body re-evaluates → HFMapView.updateUIView called
        └── context.coordinator.lastColorScheme != newScheme
              → refreshOverlayRenderers: remove + re-add all overlays
                    → mapView(_:rendererFor:) called for each
                          → NoiseSmokeRenderer(isDark: true/false) instantiated with correct colors
```

---

## Scalability Considerations

| Concern | At current scale (10 layers, 1 user) | If features expand |
|---------|--------------------------------------|-------------------|
| ResponseCache disk usage | ~5-10 MB per layer (GeoJSON responses) | Enforce per-file size limit in `store()`, evict LRU if total exceeds 50 MB |
| FavoritesStore query performance | Trivial (<50 records) | SwiftData handles thousands; no optimization needed for v1 |
| Share image generation | ~100ms for 1334×750 frame, imperceptible | If compositing becomes slow, move `buildShareImage` to background task |
| Dark mode overlay refresh | O(n overlays), fires once per scheme change | Already gated on scheme change; no concern |

---

## Sources

- Swift by Sundell — Caching in Swift: NSCache patterns, TTL, disk persistence — MEDIUM confidence (community source, well-established)
- Apple Developer Documentation — MKMapSnapshotter: does not capture custom overlays — HIGH confidence (official)
- BleepingSwift — AppStorage vs UserDefaults vs SwiftData: SwiftData for structured iOS 17+ data — HIGH confidence (aligned with Apple docs)
- SwiftLee — Dark Mode support in UIKit: `traitCollectionDidChange`, `hasDifferentColorAppearance` — HIGH confidence (well-established pattern)
- Hacking with Swift — `UIGraphicsImageRenderer.drawHierarchy` for view capture — HIGH confidence (official API, community verified)
- NSHipster — URLCache: HTTP-level caching limitations without `Cache-Control` headers — HIGH confidence (well-established reference)
- Apple Developer Forums — `traitCollectionDidChange` not called on coordinators (only on UIView/UIViewController subclasses) — HIGH confidence (official forums)
