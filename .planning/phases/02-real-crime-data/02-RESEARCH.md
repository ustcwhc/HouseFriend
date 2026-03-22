# Phase 2: Real Crime Data - Research

**Researched:** 2026-03-22
**Domain:** Socrata SODA API integration, spatial density grids, multi-city crime data routing
**Confidence:** MEDIUM-HIGH

## Summary

Phase 2 replaces the hardcoded Gaussian crime model with real incident data from government open data APIs. Research confirms that **SF Open Data** and **Oakland CrimeWatch Maps** are viable Socrata SODA endpoints with geographic coordinates, but **San Jose and Berkeley require different approaches** than originally assumed.

San Jose uses CKAN (not Socrata) and its police dataset has no latitude/longitude fields -- only block-level street addresses. Berkeley's Socrata portal (`data.cityofberkeley.info`) has a Calls-for-Service dataset with a `Block_Location` geo field, but the portal returns 403 on programmatic API access (possibly bot protection or authentication required). These findings mean v1 should ship with **SF + Oakland only** for the crime heatmap, with San Jose and Berkeley deferred until geocoding or alternative data sources can be validated.

The Oakland CrimeWatch Data dataset (`ppgh-7dqv`) referenced in CONTEXT.md and STACK.md has **no latitude/longitude fields** -- only street addresses. The correct Oakland dataset is **CrimeWatch Maps Past 90-Days** (`ym6k-rx7a`), which includes a `location_1` GeoJSON Point field with coordinates. Socrata app tokens work cross-instance (one registration at `data.sfgov.org` works on `data.oaklandca.gov`). The `within_circle` geographic filter is confirmed working on the Oakland Maps dataset.

**Primary recommendation:** Build a 2-city crime data system (SF + Oakland) using Socrata SODA API with density grid rendering, and design the city endpoint registry to be extensible for future cities. Drop San Jose and Berkeley from Phase 2 scope.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
1. **Heatmap Transition: Density Grid** -- Replace hardcoded Gaussian model with density grid built from real API incidents. Grid cells ~0.005 deg, normalize to 0-1 intensity, existing color mapping unchanged.
2. **Crime Cluster UX: Grid-Cell Markers** -- Numbered `MKAnnotation` cluster markers per grid cell when Details toggle enabled. Tap zooms into area. Colors by severity (red/orange/gray).
3. **Multi-City Routing: Query All, Merge** -- Query all available city APIs for viewport, merge into single incident set. City endpoint registry with bounding boxes.
4. **Data Recency: 90-Day Rolling Window, Equal Weight** -- Fetch last 90 days, no temporal weighting, 24hr cache TTL.

### Claude's Discretion
- Grid cell size (CONTEXT.md suggests 0.005 deg, research should validate)
- Density normalization approach
- City bounding box definitions
- Error banner UI specifics

### Deferred Ideas (OUT OF SCOPE)
- More Bay Area cities beyond the 4 named (Fremont, Richmond, etc.)
- Crime type filtering UI
- Historical trend view (ADV-01)

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CRIME-01 | Crime heatmap renders from real SF Open Data SODA API incidents | SF dataset `wg3w-h783` verified with 33 fields including `latitude`, `longitude`, `point` GeoJSON, `incident_category`, `incident_date`. `within_circle(point,lat,lon,radius)` confirmed. |
| CRIME-02 | Crime heatmap renders from real Oakland CrimeWatch SODA API incidents | **CORRECTED:** Use `ym6k-rx7a` (CrimeWatch Maps Past 90-Days), NOT `ppgh-7dqv` (no coordinates). `location_1` GeoJSON Point field confirmed with `within_circle` support. |
| CRIME-03 | API requests include explicit `$limit` and `$where` bounding box | SODA default is 1,000 rows. Always pass `$limit=5000` and `$where=within_circle(...)` to avoid silent truncation. Max 50,000 per request. |
| CRIME-04 | Requests include registered Socrata app token | One token works cross-instance. Register at `data.sfgov.org/profile/app_tokens`. Pass as `$$app_token` query param or `X-App-Token` header. |
| CRIME-05 | Multi-city routing selects SF vs Oakland endpoint based on coordinate location | City endpoint registry with bounding boxes. SF and Oakland confirmed. San Jose (CKAN, no coords) and Berkeley (403 access issues) deferred. |
| CRIME-06 | Field-presence validation surfaces visible error banner on schema changes | Current code silently falls back to mock data. Must validate required fields before parsing and show banner on failure. |
| CRIME-07 | Crime layer shows data recency label | SODA `$where=incident_date > '${90_days_ago}'` for SF; `datetime > '${90_days_ago}'` for Oakland. Display "Based on incidents from last 90 days" in report. |
| CRIME-08 | Crime detail toggle shows numbered cluster markers on heatmap | Reuse density grid cells as annotation source. Each cell with incidents > 0 gets an `MKAnnotation` with count. |
| CRIME-09 | Cluster markers aggregate by area and display crime count numbers | Grid-cell markers with numbered circles. Color by severity tier. Tap to zoom. |

</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Foundation/URLSession | iOS 17+ | HTTP requests to SODA APIs | Native, already used in project |
| MapKit (MKTileOverlay) | iOS 17+ | Density grid heatmap rendering | Already used in `CrimeTileOverlay` |
| MapKit (MKAnnotation) | iOS 17+ | Cluster markers for detail toggle | Already used in `HFAnnotation` system |
| JSONSerialization | iOS 17+ | Parse SODA JSON responses | Already used in `CrimeService.parseIncidents` |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ResponseCache | Phase 1 | Cache crime API responses (24hr TTL) | Every API call goes through cache first |
| os.Logger | iOS 17+ | Structured logging for network/scoring | Already configured in AppLogger |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| JSONSerialization | Codable structs | Codable is cleaner but SODA field names vary per city; JSONSerialization gives flexibility for per-city field mapping without separate Codable types per dataset |
| Direct URLSession | async/await URLSession | Project convention uses callback-based `dataTask`; mixing patterns adds confusion. Stick with callbacks for consistency. |

**No new dependencies needed.** Everything uses native frameworks already in the project.

## Architecture Patterns

### Recommended Project Structure

```
HouseFriend/
  Services/
    CrimeService.swift        # Expanded: multi-city routing, density grid builder
  Models/
    CrimeMarker.swift          # Existing: reuse for cluster annotations
    CrimeIncident.swift        # Extract from CrimeService (currently inline)
    DensityGrid.swift          # NEW: spatial grid data structure
    CityEndpoint.swift         # NEW: city API registry model
  Views/
    CrimeTileOverlay.swift     # Modified: crimeValue() reads from density grid
    HFMapView.swift            # Modified: cluster annotation rendering
    ContentView.swift          # Modified: refreshCrimeIncidents uses real data
```

### Pattern 1: City Endpoint Registry

**What:** A static registry mapping cities to their SODA API configurations (base URL, dataset ID, field mappings, bounding box).

**When to use:** Every crime data fetch. The service checks which cities overlap the viewport and fires parallel requests.

**Example:**
```swift
struct CityEndpoint {
    let name: String
    let baseURL: String       // e.g., "https://data.sfgov.org/resource/wg3w-h783.json"
    let boundingBox: MKCoordinateRegion
    let fieldMapping: FieldMapping

    struct FieldMapping {
        let latitude: String      // "latitude" for SF, extracted from "location_1" for Oakland
        let longitude: String
        let category: String      // "incident_category" for SF, "crimetype" for Oakland
        let datetime: String      // "incident_date" for SF, "datetime" for Oakland
        let description: String   // "incident_description" for SF, "description" for Oakland
        let geoColumn: String     // "point" for SF, "location_1" for Oakland
    }
}
```

### Pattern 2: Density Grid

**What:** A 2D array of incident counts covering a geographic region, used by `CrimeTileOverlay.crimeValue()` for heatmap rendering and by the cluster marker generator.

**When to use:** After fetching and merging incidents from all city endpoints.

**Example:**
```swift
struct DensityGrid {
    let origin: CLLocationCoordinate2D  // SW corner
    let cellSize: Double                // degrees per cell (0.005)
    let rows: Int                       // latitude divisions
    let cols: Int                       // longitude divisions
    let counts: [[Int]]                 // [row][col] incident counts
    let maxCount: Int                   // for normalization

    /// Returns normalized 0.0-1.0 intensity for a coordinate
    func intensity(lat: Double, lon: Double) -> Double {
        let row = Int((lat - origin.latitude) / cellSize)
        let col = Int((lon - origin.longitude) / cellSize)
        guard row >= 0, row < rows, col >= 0, col < cols else { return 0.0 }
        guard maxCount > 0 else { return 0.0 }
        return Double(counts[row][col]) / Double(maxCount)
    }
}
```

**Grid cell size validation:** 0.005 degrees is approximately 550m latitude x 400m longitude at Bay Area latitudes (37.7N). This produces roughly 8-10 cells across a typical neighborhood view. At zoom level 14, a tile covers ~0.022 degrees, so each tile would contain ~4x4 grid cells -- sufficient resolution without excessive computation.

### Pattern 3: CrimeTileOverlay Grid Integration

**What:** Replace the hardcoded `crimeValue(lat:lon:)` Gaussian function with a density grid lookup.

**When to use:** The density grid is set on the overlay as a property; `loadTile()` reads from it.

**Example:**
```swift
class CrimeTileOverlay: MKTileOverlay {
    var densityGrid: DensityGrid?  // Set by CrimeService after fetch

    static func crimeValue(lat: Double, lon: Double, grid: DensityGrid?) -> Double {
        guard let grid = grid else { return 0.10 }  // No data = minimal base
        let raw = grid.intensity(lat: lat, lon: lon)
        // Map raw 0-1 to visual range 0.10-1.0 (avoid zero = invisible)
        return max(0.10, min(1.0, 0.10 + raw * 0.90))
    }
}
```

**Key change:** `crimeValue` becomes an instance method (or takes a grid parameter) instead of using static hotspot arrays. The existing `crimeRGB()` and alpha formula remain unchanged.

**Tile invalidation:** When the density grid updates (new fetch), call `MKMapView.removeOverlay()` then `addOverlay()` to force MapKit to re-request all visible tiles with the new data.

### Pattern 4: Cluster Marker Generation from Grid

**What:** Convert density grid cells with counts > 0 into `CrimeMarker` annotations for the detail toggle.

**When to use:** When `showCrimeDetails` is toggled on and a density grid exists.

```swift
func clusterMarkers(from grid: DensityGrid) -> [CrimeMarker] {
    var markers: [CrimeMarker] = []
    for row in 0..<grid.rows {
        for col in 0..<grid.cols {
            let count = grid.counts[row][col]
            guard count > 0 else { continue }
            let lat = grid.origin.latitude + Double(row) * grid.cellSize + grid.cellSize / 2
            let lon = grid.origin.longitude + Double(col) * grid.cellSize + grid.cellSize / 2
            markers.append(CrimeMarker(
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                type: count > 10 ? .violent : count > 5 ? .property : .other,
                count: count,
                daysAgo: 0  // aggregate, not per-incident
            ))
        }
    }
    return markers
}
```

### Anti-Patterns to Avoid

- **Geocoding street addresses at runtime:** San Jose and Oakland (`ppgh-7dqv`) have address-only data. Do NOT use `CLGeocoder` to batch-geocode -- it has strict rate limits (1 request/second) and would require hundreds of calls. Only use datasets with coordinates.
- **Storing the density grid in `UserDefaults` or disk:** The grid is derived data, cheap to recompute from cached API responses. Store raw API JSON in `ResponseCache`, rebuild grid on demand.
- **Fetching all incidents without bounding box:** Without `within_circle`, a query for "last 90 days" in SF returns 50K+ rows. Always spatially constrain.
- **Hardcoding Oakland field names from `ppgh-7dqv`:** That dataset has no coordinates. Use `ym6k-rx7a` instead.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Spatial indexing | Custom R-tree for incident lookup | Simple 2D array grid (DensityGrid) | Grid cell lookup is O(1); incident counts at Bay Area scale (5K-10K per viewport) don't need a spatial index |
| Geocoding addresses | CLGeocoder batch processing | Pre-geocoded datasets only | CLGeocoder rate-limited to 1/sec; would need 1000+ calls for Oakland ppgh-7dqv |
| Tile caching | Custom tile image cache | MapKit's built-in MKTileOverlay cache | MapKit automatically caches rendered tiles; just invalidate on grid change |
| HTTP request deduplication | Custom in-flight request tracker | ResponseCache with 24hr TTL | Cache prevents duplicate fetches; 24hr TTL matches data update cadence |

## Common Pitfalls

### Pitfall 1: Socrata 1,000-Row Silent Truncation
**What goes wrong:** Queries without explicit `$limit` return only 1,000 rows with no warning. The heatmap appears sparse in high-crime areas.
**Why it happens:** SODA default limit is 1,000 rows. No error or truncation header is returned.
**How to avoid:** Always include `$limit=5000` (or higher) AND a `$where=within_circle(...)` to spatially constrain results. Log returned row count and warn if it equals the limit.
**Warning signs:** Downtown SF queries returning exactly 1,000 rows.

### Pitfall 2: Wrong Oakland Dataset (ppgh-7dqv Has No Coordinates)
**What goes wrong:** Using Oakland CrimeWatch Data (`ppgh-7dqv`) results in address-only data that cannot be plotted on a map without geocoding.
**Why it happens:** STACK.md and CONTEXT.md reference `ppgh-7dqv` as the Oakland dataset, but it lacks latitude/longitude fields.
**How to avoid:** Use **CrimeWatch Maps Past 90-Days** (`ym6k-rx7a`) instead. It has a `location_1` field with GeoJSON Point coordinates.
**Warning signs:** Parse failures when looking for latitude/longitude fields; all Oakland incidents missing coordinates.

### Pitfall 3: Oakland GeoJSON Coordinate Order
**What goes wrong:** Oakland's `location_1.coordinates` are `[longitude, latitude]` (GeoJSON standard), not `[latitude, longitude]`.
**Why it happens:** GeoJSON follows [x, y] = [lon, lat] convention, opposite of most iOS APIs.
**How to avoid:** Always extract as `coordinates[0]` = longitude, `coordinates[1]` = latitude. Add a unit test for this.
**Warning signs:** Oakland incidents plotting in the ocean or Antarctica.

### Pitfall 4: SF vs Oakland Field Name Mismatch
**What goes wrong:** Using SF field names (`incident_category`, `incident_date`, `latitude`) on Oakland data fails silently.
**Why it happens:** Each Socrata portal defines its own schema. SF uses `incident_category`; Oakland uses `crimetype`.
**How to avoid:** Use the city endpoint registry pattern with per-city field mappings.
**Warning signs:** All Oakland incidents failing to parse; zero Oakland incidents on map.

### Pitfall 5: Silent Fallback to Mock Data on Parse Failure
**What goes wrong:** Current `CrimeService` catches parse failures and falls back to `loadMockData()`, hiding API schema changes from users.
**Why it happens:** The original code was written for prototype resilience, not data accuracy.
**How to avoid:** Add field-presence validation that checks for required fields BEFORE parsing. If fields are missing, set `errorMessage` to surface a banner, do NOT fall back to mock data.
**Warning signs:** Users see "crime data" that is actually random Gaussian noise with no warning.

### Pitfall 6: Density Grid Stale After Viewport Change
**What goes wrong:** User pans to a new area but the density grid still reflects the old region, showing incorrect heatmap colors.
**Why it happens:** Grid is built for a specific bounding box. Panning outside that box means grid lookups return 0.
**How to avoid:** Track the grid's coverage region. When the viewport moves significantly outside it (e.g., >50% outside cached region), trigger a re-fetch and grid rebuild. Use the existing `ResponseCache` grid-cell cache key pattern to determine if data exists for the new viewport.
**Warning signs:** Blank/minimal heatmap after panning; heatmap that "snaps" to new data after a delay.

### Pitfall 7: CrimeTileOverlay Thread Safety
**What goes wrong:** Density grid is updated on main thread while `loadTile()` reads it on background threads, causing crashes or corrupted reads.
**Why it happens:** `MKTileOverlay.loadTile()` runs on a background queue. Setting a new grid property from the main thread creates a race.
**How to avoid:** Make the density grid property atomic (use a serial queue or `os_unfair_lock` for reads/writes), OR create a new `CrimeTileOverlay` instance with each grid update and swap it on the map.
**Warning signs:** Intermittent crashes in `loadTile`, EXC_BAD_ACCESS on grid access.

## Code Examples

### SF Open Data Query (90-day window, spatial filter)
```swift
// Source: Verified against live API response 2026-03-22
let ninetyDaysAgo = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-90 * 86400))
let urlString = """
    https://data.sfgov.org/resource/wg3w-h783.json\
    ?$where=within_circle(point,\(lat),\(lon),\(radiusMeters))\
     AND incident_date > '\(ninetyDaysAgo)'\
    &$limit=5000\
    &$$app_token=\(appToken)
    """
```

**SF field names (verified):** `latitude`, `longitude`, `point` (GeoJSON), `incident_category`, `incident_subcategory`, `incident_description`, `incident_date`, `incident_datetime`, `report_datetime`, `police_district`, `analysis_neighborhood`, `resolution`

### Oakland CrimeWatch Maps Query (correct dataset)
```swift
// Source: Verified against live API response for ym6k-rx7a, 2026-03-22
let urlString = """
    https://data.oaklandca.gov/resource/ym6k-rx7a.json\
    ?$where=within_circle(location_1,\(lat),\(lon),\(radiusMeters))\
     AND datetime > '\(ninetyDaysAgo)'\
    &$limit=5000\
    &$$app_token=\(appToken)
    """
```

**Oakland field names (verified from ym6k-rx7a):** `crimetype`, `datetime`, `casenumber`, `description`, `policebeat`, `address`, `city`, `state`, `location_1` (GeoJSON Point with `.coordinates[0]` = lon, `.coordinates[1]` = lat)

### Parsing Oakland GeoJSON Coordinates
```swift
// Source: Verified from live ym6k-rx7a response
func parseOaklandIncident(_ item: [String: Any]) -> CrimeIncident? {
    guard let crimeType = item["crimetype"] as? String,
          let location = item["location_1"] as? [String: Any],
          let coords = location["coordinates"] as? [Double],
          coords.count >= 2 else { return nil }
    // GeoJSON: [longitude, latitude]
    let lon = coords[0]
    let lat = coords[1]
    guard lat.isFinite, lon.isFinite else { return nil }
    return CrimeIncident(
        category: crimeType,
        description: item["description"] as? String ?? crimeType,
        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
        date: parseSODADate(item["datetime"] as? String)
    )
}
```

### Field Presence Validation (CRIME-06)
```swift
func validateFields(_ json: [[String: Any]], required: [String]) -> [String] {
    guard let first = json.first else { return ["Empty response"] }
    return required.filter { first[$0] == nil }
}

// Usage:
let missing = validateFields(json, required: endpoint.fieldMapping.requiredFields)
if !missing.isEmpty {
    DispatchQueue.main.async {
        self.errorMessage = "Crime data schema changed: missing \(missing.joined(separator: ", "))"
    }
    return  // Do NOT fall back to mock data
}
```

## API Field Schema Reference

### SF Open Data (`wg3w-h783`) -- HIGH confidence

| Field | Type | Use |
|-------|------|-----|
| `latitude` | String (parseable Double) | Direct coordinate |
| `longitude` | String (parseable Double) | Direct coordinate |
| `point` | GeoJSON Point | `within_circle` filter target |
| `incident_category` | String | Crime type classification |
| `incident_date` | ISO 8601 datetime | Date filter, recency |
| `incident_description` | String | Detail display |
| `police_district` | String | Area identification |
| `analysis_neighborhood` | String | Neighborhood name |

### Oakland CrimeWatch Maps (`ym6k-rx7a`) -- HIGH confidence

| Field | Type | Use |
|-------|------|-----|
| `location_1` | GeoJSON Point (`{"type":"Point","coordinates":[-122.xx,37.xx]}`) | Coordinates + `within_circle` filter target |
| `crimetype` | String | Crime type classification |
| `datetime` | ISO 8601 datetime | Date filter, recency |
| `description` | String | Detail display |
| `policebeat` | String | Area identification |
| `address` | String | Block-level address |
| `casenumber` | String | Unique identifier |

### San Jose (`data.sanjoseca.gov`) -- BLOCKED for Phase 2

| Property | Status |
|----------|--------|
| Platform | CKAN (NOT Socrata) |
| Dataset | Police Calls for Service 2026 (resource `dc0ec99c-...`) |
| Fields | `CALL_TYPE`, `OFFENSE_DATE`, `ADDRESS`, `CITY`, `STATE` |
| Coordinates | **NONE** -- no latitude/longitude fields |
| API | CKAN DataStore API, not SODA |
| Recommendation | **Defer** -- would require batch geocoding of addresses |

### Berkeley (`data.cityofberkeley.info`) -- BLOCKED for Phase 2

| Property | Status |
|----------|--------|
| Platform | Socrata |
| Dataset | Berkeley PD Calls for Service (`k2nh-s5h5`) |
| Fields | `CASENO`, `OFFENSE`, `EVENTDT`, `EVENTTM`, `CVLEGEND`, `CVDOW`, `Block_Location`, `BLKADDR`, `City`, `State` |
| Coordinates | `Block_Location` is Socrata Location type (likely has lat/lon) -- **UNVERIFIED** |
| API Access | Returns **HTTP 403** on all programmatic requests tested |
| Data Type | Calls for service, not crime incidents |
| Recommendation | **Defer** -- 403 access issue must be resolved first; data is CFS not crime |

## City Bounding Boxes

For the endpoint registry, use these approximate bounding boxes:

| City | SW Lat | SW Lon | NE Lat | NE Lon |
|------|--------|--------|--------|--------|
| San Francisco | 37.708 | -122.515 | 37.812 | -122.357 |
| Oakland | 37.733 | -122.335 | 37.885 | -122.115 |

**Overlap handling:** When the viewport spans both cities, fire parallel requests to both endpoints and merge results before building the density grid.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcoded Gaussian hotspots | Real incident density grid | This phase | Heatmap reflects actual crime patterns |
| Single SF endpoint | Multi-city endpoint registry | This phase | Oakland coverage added |
| Silent mock data fallback | Error banner on schema change | This phase | Users see when data is unavailable |
| Random mock markers for Details toggle | Grid-cell cluster markers from real data | This phase | Accurate incident count display |

**Deprecated/outdated:**
- Oakland dataset `ppgh-7dqv` (CrimeWatch Data): No coordinates. Use `ym6k-rx7a` (CrimeWatch Maps) instead.
- Oakland dataset `vmz9-uktm` (Crime Data 15X v2): Also no coordinates per live test.

## Open Questions

1. **Socrata app token registration scope**
   - What we know: One token registered at `data.sfgov.org` works on `data.oaklandca.gov` (confirmed by Socrata docs -- tokens work cross-instance).
   - What's unclear: Whether the token needs to be registered at one portal specifically, or any portal works.
   - Recommendation: Register at `data.sfgov.org` (primary), test with Oakland endpoint before shipping.

2. **Optimal `$limit` value**
   - What we know: Default is 1,000 (silent truncation). Max is 50,000 per request.
   - What's unclear: How many incidents a 1km radius in downtown SF returns over 90 days.
   - Recommendation: Start with `$limit=5000`. Log actual returned counts. If any query returns exactly 5,000, increase the limit or add pagination.

3. **Grid cell size tuning**
   - What we know: 0.005 degrees = ~550m x 400m cells. Reasonable for neighborhood-level view.
   - What's unclear: Whether this is too coarse for zoomed-in views or too fine for zoomed-out views.
   - Recommendation: Start with 0.005 degrees. Could make it zoom-dependent in a future iteration (smaller cells at higher zoom).

4. **Berkeley API 403 resolution**
   - What we know: `data.cityofberkeley.info` returns 403 on all API endpoints tested (JSON, CSV, metadata).
   - What's unclear: Whether this is permanent (API deprecated), temporary (maintenance), or requires authentication.
   - Recommendation: Defer Berkeley to a future phase. Check back periodically.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (`import Testing`, `@Test`, `#expect`) |
| Config file | Xcode project target `HouseFriendTests` |
| Quick run command | `xcodebuild test -scheme HouseFriend -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:HouseFriendTests 2>&1 \| tail -20` |
| Full suite command | `xcodebuild test -scheme HouseFriend -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 \| tail -40` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CRIME-01 | SF incidents parsed from real SODA response | unit | `xcodebuild test -only-testing:HouseFriendTests/CrimeServiceTests/testParseSFIncidents` | Wave 0 |
| CRIME-02 | Oakland incidents parsed from ym6k-rx7a response | unit | `xcodebuild test -only-testing:HouseFriendTests/CrimeServiceTests/testParseOaklandIncidents` | Wave 0 |
| CRIME-03 | Query includes explicit $limit and $where | unit | `xcodebuild test -only-testing:HouseFriendTests/CrimeServiceTests/testQueryIncludesLimitAndWhere` | Wave 0 |
| CRIME-04 | Requests include app token | unit | `xcodebuild test -only-testing:HouseFriendTests/CrimeServiceTests/testRequestIncludesAppToken` | Wave 0 |
| CRIME-05 | Correct endpoint selected for SF vs Oakland coordinates | unit | `xcodebuild test -only-testing:HouseFriendTests/CrimeServiceTests/testCityRouting` | Wave 0 |
| CRIME-06 | Missing fields surface error, no mock fallback | unit | `xcodebuild test -only-testing:HouseFriendTests/CrimeServiceTests/testFieldValidationError` | Wave 0 |
| CRIME-07 | Recency label present in stats | unit | `xcodebuild test -only-testing:HouseFriendTests/CrimeServiceTests/testRecencyLabel` | Wave 0 |
| CRIME-08 | Density grid produces cluster markers | unit | `xcodebuild test -only-testing:HouseFriendTests/DensityGridTests/testClusterMarkerGeneration` | Wave 0 |
| CRIME-09 | Cluster markers have correct counts | unit | `xcodebuild test -only-testing:HouseFriendTests/DensityGridTests/testMarkerCounts` | Wave 0 |

### Sampling Rate
- **Per task commit:** Quick run of changed test file
- **Per wave merge:** Full suite
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `HouseFriendTests/CrimeServiceTests.swift` -- covers CRIME-01 through CRIME-07 (parse, routing, validation)
- [ ] `HouseFriendTests/DensityGridTests.swift` -- covers CRIME-08, CRIME-09 (grid building, cluster markers, intensity lookup)
- [ ] Test fixtures: sample SF JSON response, sample Oakland JSON response, sample malformed response

## Sources

### Primary (HIGH confidence)
- [SF Open Data SFPD Incident Reports](https://data.sfgov.org/resource/wg3w-h783.json) -- field schema verified via live API response (33 fields including `latitude`, `longitude`, `point`)
- [Oakland CrimeWatch Maps Past 90-Days](https://data.oaklandca.gov/resource/ym6k-rx7a.json) -- field schema verified via live API response (`location_1` GeoJSON Point confirmed)
- [Socrata App Tokens documentation](https://dev.socrata.com/docs/app-tokens.html) -- cross-instance usage confirmed
- [Socrata within_circle documentation](https://dev.socrata.com/docs/functions/within_circle) -- GeoJSON coordinate order documented
- [San Jose Open Data Portal](https://data.sanjoseca.gov/dataset/police-calls-for-service) -- CKAN platform confirmed, field schema verified via CKAN DataStore API

### Secondary (MEDIUM confidence)
- [Berkeley PD Calls for Service](https://data.cityofberkeley.info/Public-Safety/Berkeley-PD-Calls-for-Service/k2nh-s5h5) -- field names from search results (CASENO, OFFENSE, EVENTDT, Block_Location); API access returns 403
- [Oakland CrimeWatch Data ppgh-7dqv](https://data.oaklandca.gov/resource/ppgh-7dqv.json) -- verified NO coordinate fields (address only)
- [Oakland Crime Data 15X v2 vmz9-uktm](https://data.oaklandca.gov/resource/vmz9-uktm.json) -- verified NO coordinate fields (address only)

### Tertiary (LOW confidence)
- Berkeley `Block_Location` field type -- inferred as Socrata Location type from common Socrata patterns, but not directly verified due to 403 access

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all native frameworks, no new dependencies
- Architecture: HIGH -- density grid pattern is straightforward; field schemas verified from live APIs
- API schemas (SF): HIGH -- verified from live response
- API schemas (Oakland ym6k-rx7a): HIGH -- verified from live response with `within_circle`
- API schemas (San Jose): HIGH -- verified CKAN, confirmed no coordinates = unusable
- API schemas (Berkeley): LOW -- 403 access, field names from secondary sources only
- Pitfalls: HIGH -- based on verified API behavior and existing codebase analysis

**Research date:** 2026-03-22
**Valid until:** 2026-04-22 (government data portals are stable; re-verify field schemas if builds fail)
