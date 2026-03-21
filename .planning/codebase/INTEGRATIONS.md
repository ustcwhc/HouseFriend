# External Integrations

**Analysis Date:** 2026-03-21

## APIs & External Services

**Air Quality:**
- Open-Meteo Air Quality API — real-time US AQI, PM2.5 data
  - Endpoint: `https://air-quality-api.open-meteo.com/v1/air-quality`
  - Auth: None (completely free, no API key)
  - Client: `URLSession.shared` in `HouseFriend/Services/AirQualityService.swift`
  - Fallback: hardcoded moderate AQI (52) on failure

**Earthquakes:**
- USGS Earthquake Hazards API (FDSNWS) — past 30 days, M≥2.5, Bay Area bounding box
  - Endpoint: `https://earthquake.usgs.gov/fdsnws/event/1/query`
  - Auth: None (public federal data)
  - Response format: GeoJSON decoded via `Codable` structs
  - Client: `URLSession.shared` in `HouseFriend/Services/EarthquakeService.swift`

**Crime:**
- SF Open Data Socrata API — recent incidents, ordered by report_datetime DESC
  - Endpoint: `https://data.sfgov.org/resource/wg3w-h783.json`
  - Auth: None (public open data, limit 100 records)
  - Client: `URLSession.shared` in `HouseFriend/Services/CrimeService.swift`
  - Fallback: mock data with Bay Area crime pattern estimates on failure or empty response

**Noise / Road Data (dynamic tier):**
- OpenStreetMap Overpass API — roads and railways within map viewport on demand
  - Primary mirror: `https://overpass-api.de/api/interpreter`
  - Fallback mirror: `https://overpass.kumi.systems/api/interpreter`
  - Auth: None (free OSM infrastructure)
  - Protocol: HTTP POST with `data=<OverpassQL query>`
  - Timeout: 28 seconds per request, 25-second query timeout in QL
  - Client: `URLSession.shared` in `HouseFriend/Services/NoiseService.swift`
  - Fallback: static bundled `bayarea_roads.json.gz` on network failure
  - Known issue: Overpass can time out on macOS; works reliably on iOS device

**Electric Transmission Lines:**
- HIFLD (Homeland Infrastructure Foundation-Level Data) ArcGIS REST API — power line geometries
  - Endpoint: `https://services1.arcgis.com/Hp6G80Pky0om7QvQ/arcgis/rest/services/Electric_Power_Transmission_Lines/FeatureServer/0/query`
  - Auth: None (public federal GIS data)
  - Response format: GeoJSON decoded via custom `Codable` structs
  - Client: `URLSession.shared` in `HouseFriend/Services/ElectricLinesService.swift`
  - Fallback: 4 hardcoded PG&E corridor approximations on failure

## Data Storage

**Databases:**
- None — no local database or cloud database

**File Storage:**
- App bundle only — two read-only GeoJSON assets:
  - `HouseFriend/bayarea_roads.json.gz` (514 KB gzip, ~15K road segments)
  - `HouseFriend/bayarea_zips.json` (693 KB, 445 ZIP polygons)
- No user-generated file storage
- No iCloud or CloudKit integration

**Caching:**
- MapKit tile cache — `CrimeTileOverlay` tiles cached automatically by `MKTileOverlay` (permanent, MapKit-managed)
- No explicit disk cache for network responses
- Per-session in-memory: each service holds fetched data in `@Published` properties until app restart

## Authentication & Identity

**Auth Provider:**
- None — the app has no user accounts, login, or authentication system

**Location Permission:**
- `CLLocationManager.requestWhenInUseAuthorization()` — iOS system prompt
- Usage description set in build settings: "HouseFriend uses your location to analyze neighborhood safety, air quality, earthquake risk, and more."
- Implementation: `HouseFriend/Services/LocationService.swift`

## Address Search

**MapKit Local Search:**
- `MKLocalSearchCompleter` — fuzzy autocomplete biased to Bay Area region
- `MKLocalSearch` — resolves selected completion to `MKMapItem` with coordinate
- No external API key required (Apple Maps backend)
- Implementation: `HouseFriend/Services/SearchCompleterService.swift`
- Region bias: centered at (37.650, -122.100), span 2.0° lat/lon

## Monitoring & Observability

**Error Tracking:**
- None (no Crashlytics, Sentry, etc.)

**Logs:**
- `os.Logger` via `HouseFriend/Services/AppLogger.swift`
- Four subsystem loggers: `network`, `scoring`, `location`, `map`
- Visible in Xcode console and macOS Console.app under subsystem `com.housefriend`
- Pattern: `AppLogger.network.error("...")` or `.warning(...)` or `.info(...)`

## CI/CD & Deployment

**Hosting:**
- iOS App Store (target: Wancoco.HouseFriend)

**CI Pipeline:**
- Not detected — no GitHub Actions, Fastlane, or other CI configuration files present

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

## Static / Hardcoded Data Sources

Several layers use embedded Swift data instead of live APIs. These are treated as bundled datasets, not integrations, but are worth noting for maintenance:

| Service | Source | Record Count |
|---------|--------|--------------|
| `HouseFriend/Services/SchoolService.swift` | Hardcoded Swift arrays by county | 130+ schools |
| `HouseFriend/Services/FireDataService.swift` | Hardcoded polygon coordinates | 22 fire hazard zones |
| `HouseFriend/Services/SuperfundService.swift` | Hardcoded EPA NPL site list | 62 sites |
| `HouseFriend/Services/SupportiveHousingService.swift` | Hardcoded facility list | 35+ facilities |
| `HouseFriend/Services/PopulationService.swift` | Hardcoded city census data | 65 Bay Area cities |
| `HouseFriend/Services/ElectricLinesService.swift` (mock fallback) | Hardcoded PG&E corridor approximations | 4 lines |

## Data Fetch Script

- `scripts/fetch_bayarea_roads.py` — Python 3 script that queries Overpass API and writes `HouseFriend/bayarea_roads.json`
- Run manually by developers to regenerate the bundled road dataset
- Not part of the build pipeline

---

*Integration audit: 2026-03-21*
