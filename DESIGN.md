# Design Decisions

> Records the "why" behind key architectural choices. Each entry captures the problem, alternatives considered, and the chosen approach.

---

## D001 - UIKit MKMapView over SwiftUI Map

**Problem:** SwiftUI's native `Map` view couldn't handle our overlay requirements.

**Alternatives considered:**
1. SwiftUI `Map` with `MapPolyline` — O(n) view rebuilds with hundreds of roads, UI freezes
2. SwiftUI `Map` with `.overlay()` — screen-space coordinates, overlays don't follow map dragging
3. UIKit `MKMapView` via `UIViewRepresentable` — full control, native coordinate space

**Decision:** Option 3. All overlays stay in MapKit coordinate space, perfectly following pan/zoom. Trade-off: more boilerplate, but correct behavior.

---

## D002 - Bundled JSON over Swift Literals for Large Data

**Problem:** 445 ZIP polygons embedded as Swift array literals (32K lines) caused SourceKitService to consume >10GB RAM and crash Xcode.

**Decision:** Bundle data as JSON files loaded at runtime. `bayarea_zips.json` (693 KB) + 65-line parser. Same approach for `bayarea_roads.json.gz` (514 KB).

**Rule:** Never embed datasets >1K lines as Swift literals. Always use bundled JSON.

---

## D003 - Two-Tier Noise Loading

**Problem:** Overpass API is slow (~2-5s) and can timeout. Users expect instant response when switching to noise layer.

**Alternatives considered:**
1. Overpass-only — slow, unreliable
2. Fully bundled — file too large for residential streets
3. Two-tier: bundled majors + on-demand detail — instant at City zoom, detail at Neighborhood zoom

**Decision:** Option 3. Bundle 15K major roads/railways as gzip (514 KB) for instant rendering. Fetch secondary/residential streets from Overpass only at Neighborhood zoom (<0.08° span).

---

## D004 - Five Canonical Zoom Tiers

**Problem:** Different layers need different visibility thresholds. Without a shared system, each layer invents its own span checks.

**Decision:** Five named tiers (Satellite/State/County/City/Neighborhood) with span thresholds (5.0°/1.2°/0.3°/0.08°). Each rendered object maps to a minimum tier. Centralized in `ZoomTier.swift`.

**Why these specific thresholds:** They align with real-world map features — at County level you see freeways, at City level you see boulevards, at Neighborhood level you see residential streets.

---

## D005 - `.sheet(isPresented:)` over `.sheet(item:)`

**Problem:** ZIP demographics panel needs seamless content switching when tapping different ZIPs. `.sheet(item:)` dismisses and re-presents on item change, causing flicker.

**Decision:** Use `.sheet(isPresented: $showZIPSheet)` with a separate `@State var selectedZIP`. Update the ZIP data first, then show — SwiftUI batches both in the same run loop, so the sheet content updates without dismiss animation.

---

## D006 - Custom Smoke Renderer for Noise

**Problem:** Standard `MKPolylineRenderer` draws flat colored lines. We wanted a visual effect that conveys "noise pollution" intuitively.

**Decision:** Custom `NoiseSmokeRenderer` (subclass of `MKOverlayRenderer`) with 4 concentric stroke layers at decreasing opacity. Creates a dark haze effect that scales with dB level. Railways get dashed core lines for visual distinction.

---

## D007 - Ray-Casting for ZIP Tap Detection

**Problem:** MapKit doesn't provide built-in polygon tap detection for `MKPolygon` overlays. Need to determine which ZIP the user tapped.

**Decision:** Implement point-in-polygon using ray-casting algorithm in `coordinateInsidePolygon()`. O(n) per polygon vertex count, but with RDP-simplified polygons (~80 points/ZIP), it's fast enough for real-time tap response (<50ms).

---

## D008 - Gaussian Model for Crime Heatmap

**Problem:** Real per-street crime data is only available for SF and partially Oakland. Need full Bay Area coverage.

**Decision:** Use Gaussian decay model with known crime hotspots. Each hotspot contributes `exp(-dist²/radius²)` with radius 2-5 miles. Provides reasonable relative comparison across the Bay Area, though not accurate at street level. Planned upgrade: integrate real crime APIs when available.

---

## D009 - Gzip Compression for Bundled Data

**Problem:** `bayarea_roads.json` was 2.9 MB uncompressed — too large for a bundled resource.

**Decision:** Gzip compress to 514 KB. Decompress at runtime using Apple's Compression framework (COMPRESSION_ZLIB). Decompression takes <50ms, negligible compared to JSON parsing.
