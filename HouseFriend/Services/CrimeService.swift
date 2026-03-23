import Foundation
import MapKit

// MARK: - Crime data models

struct CrimeIncident: Identifiable {
    let id = UUID()
    let category: String
    let description: String
    let coordinate: CLLocationCoordinate2D
    let date: Date
}

struct CrimeStats {
    let score: Int       // 0-100, higher = safer
    let label: String
    let incidentCount: Int
}

// MARK: - CrimeHotspot

/// Hotspot derived from real crime data -- coordinate + weight.
/// Moved from CrimeTileOverlay (deleted) during Mapbox migration.
struct CrimeHotspot {
    let lat: Double
    let lon: Double
    let weight: Double  // 0.0-1.0
}

// MARK: - CrimeService

class CrimeService: ObservableObject {
    @Published var incidents: [CrimeIncident] = []
    @Published var stats: CrimeStats = CrimeStats(score: 70, label: "Moderate", incidentCount: 0)
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var densityGrid: DensityGrid?
    @Published var hotspots: [CrimeHotspot] = []
    /// Per-tract crime intensity (0.0-1.0) for polygon-based heatmap rendering
    @Published var tractCrimeDensities: [String: Double] = [:]
    @Published var recencyLabel: String = ""

    // TODO: Register at data.sfgov.org/profile/app_tokens and replace
    private static let appToken = ""

    /// One-time flag to clear stale crime cache from pre-real-data era
    private var hasClearedStaleCache = false

    /// Track last fetched region to avoid redundant refetches on small pans
    private var lastFetchCenter: (lat: Double, lon: Double)?
    private var lastFetchSpan: Double = 0

    // MARK: - Public API

    /// Fetches real crime incidents from all matching city SODA APIs for the given coordinate.
    /// Census tracts for polygon-based heatmap — loaded once on init
    private lazy var censusTracts: [CensusTract] = CensusTractData.allTracts()

    /// Pre-computed per-tract crime densities from bundled data (cities without live APIs)
    private lazy var bundledTractDensities: [String: Double] = Self.loadBundledTractDensities()

    func fetchNear(lat: Double, lon: Double, span: Double = 0.06) {
        // Clear stale cache from pre-real-data era on first fetch
        if !hasClearedStaleCache {
            hasClearedStaleCache = true
            ResponseCache.shared.clearLayer(.crime)
        }

        // Skip if already loading
        guard !isLoading else { return }

        // Skip if viewport hasn't moved much (debounce small pans)
        if let last = lastFetchCenter {
            let movedLat = abs(lat - last.lat)
            let movedLon = abs(lon - last.lon)
            let threshold = max(0.01, span * 0.3)  // Must move 30% of viewport to refetch
            if movedLat < threshold && movedLon < threshold && abs(span - lastFetchSpan) < 0.1 {
                return
            }
        }

        let matchingEndpoints = CityEndpoint.endpointsForRegion(lat: lat, lon: lon, span: span)

        // Always ensure bundled densities are loaded (San Jose, etc.)
        if tractCrimeDensities.isEmpty && !bundledTractDensities.isEmpty {
            DispatchQueue.main.async {
                self.tractCrimeDensities = self.bundledTractDensities
            }
        }

        // No SODA endpoints cover this area — bundled data still shows
        guard !matchingEndpoints.isEmpty else {
            lastFetchCenter = (lat: lat, lon: lon)
            lastFetchSpan = span
            return
        }

        // Check cache first
        let cacheKey = ResponseCache.cacheKey(layer: .crime, lat: lat, lon: lon)
        if let cachedData = ResponseCache.shared.get(key: cacheKey, layer: .crime) {
            if let json = try? JSONSerialization.jsonObject(with: cachedData) as? [String: Any],
               let allIncidents = json["incidents"] as? [[[String: Any]]],
               let endpointNames = json["endpoints"] as? [String] {
                var merged: [CrimeIncident] = []
                for (index, incidents) in allIncidents.enumerated() {
                    let name = index < endpointNames.count ? endpointNames[index] : ""
                    merged.append(contentsOf: parseIncidents(from: incidents, endpointName: name))
                }
                let grid = Self.buildGrid(from: merged, lat: lat, lon: lon)
                let score = Self.densityScore(grid: grid)
                AppLogger.network.info("Crime: loaded \(merged.count) incidents from cache")
                DispatchQueue.main.async {
                    self.incidents = merged
                    self.densityGrid = grid
                    self.stats = CrimeStats(score: score, label: Self.label(score), incidentCount: merged.count)
                    self.recencyLabel = "Based on incidents from last 90 days"
                    self.isLoading = false
                }
                return
            }
        }

        isLoading = true
        errorMessage = nil

        // Socrata floating timestamps use yyyy-MM-dd'T'HH:mm:ss.SSS format (no timezone)
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        df.locale = Locale(identifier: "en_US_POSIX")
        let ninetyDaysAgo = df.string(from: Date().addingTimeInterval(-90 * 86400))
        let group = DispatchGroup()
        var allIncidents: [CrimeIncident] = []
        var allRawJSON: [[[String: Any]]] = Array(repeating: [], count: matchingEndpoints.count)
        let endpointNames: [String] = matchingEndpoints.map { $0.name }
        let lock = NSLock()

        for (index, endpoint) in matchingEndpoints.enumerated() {
            guard let url = Self.buildURL(endpoint: endpoint, lat: lat, lon: lon, since: ninetyDaysAgo, span: span) else {
                continue
            }

            group.enter()
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                defer { group.leave() }
                guard let self = self else { return }

                guard let data = data, error == nil else {
                    AppLogger.network.warning("Crime: \(endpoint.name) network error")
                    return
                }

                // Handle non-array responses (error objects from SODA)
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    AppLogger.network.warning("Crime: \(endpoint.name) returned non-array response")
                    return
                }

                // Empty results are normal (viewport outside city bounds)
                guard !json.isEmpty else {
                    AppLogger.network.info("Crime: \(endpoint.name) returned 0 results for this area")
                    return
                }

                // Field validation (CRIME-06) — only flag true schema changes
                let missing = Self.validateFields(json, required: endpoint.fieldMapping.requiredFields)
                if !missing.isEmpty {
                    AppLogger.network.error("Crime: \(endpoint.name) schema changed — missing \(missing.joined(separator: ", "))")
                    // Don't set errorMessage for schema issues — keep existing data visible
                    return
                }

                // Truncation warning
                if json.count == 5000 {
                    AppLogger.network.warning("Crime: \(endpoint.name) returned exactly 5000 rows — may be truncated")
                }

                let incidents = self.parseIncidents(from: json, endpointName: endpoint.name)
                AppLogger.network.info("Crime: \(endpoint.name) returned \(incidents.count) incidents")

                lock.lock()
                allIncidents.append(contentsOf: incidents)
                allRawJSON[index] = json
                lock.unlock()
            }.resume()
        }

        group.notify(queue: .global(qos: .userInitiated)) { [weak self] in
            guard let self = self else { return }

            // If no new incidents, keep existing data visible (don't blank the heatmap)
            guard !allIncidents.isEmpty else {
                AppLogger.network.info("Crime: no incidents returned for this viewport — keeping existing data")
                DispatchQueue.main.async { self.isLoading = false }
                self.lastFetchCenter = (lat: lat, lon: lon)
                self.lastFetchSpan = span
                return
            }

            let grid = Self.buildGrid(from: allIncidents, lat: lat, lon: lon)
            let spots = Self.buildHotspots(from: allIncidents)
            var tractDensities = Self.computeTractDensities(incidents: allIncidents, tracts: self.censusTracts)
            // Merge in pre-computed bundled densities (San Jose, etc.) — no runtime point-in-polygon
            for (tractId, density) in self.bundledTractDensities {
                if tractDensities[tractId] == nil {
                    tractDensities[tractId] = density
                }
            }
            let score = Self.densityScore(grid: grid)

            // Only cache if we got real data — never cache empty/failed results
            if !allIncidents.isEmpty {
                let cachePayload: [String: Any] = [
                    "incidents": allRawJSON,
                    "endpoints": endpointNames
                ]
                if let cacheData = try? JSONSerialization.data(withJSONObject: cachePayload) {
                    ResponseCache.shared.set(data: cacheData, key: cacheKey, layer: .crime)
                }
            }

            AppLogger.network.info("Crime: merged \(allIncidents.count) total incidents from \(matchingEndpoints.count) endpoint(s)")

            // Save last fetch position for debounce
            self.lastFetchCenter = (lat: lat, lon: lon)
            self.lastFetchSpan = span

            DispatchQueue.main.async {
                self.incidents = allIncidents
                self.densityGrid = grid
                self.hotspots = spots
                self.tractCrimeDensities = tractDensities
                self.stats = CrimeStats(score: score, label: Self.label(score), incidentCount: allIncidents.count)
                self.recencyLabel = "Based on incidents from last 90 days"
                self.errorMessage = nil
                self.isLoading = false
            }
        }
    }

    // MARK: - URL construction

    /// Builds a SODA query URL using within_circle for the viewport area.
    /// Sample size scales with viewport — larger view = fewer incidents needed.
    private static func buildURL(endpoint: CityEndpoint, lat: Double, lon: Double, since: String, span: Double) -> URL? {
        // Radius covers the viewport (span in degrees → meters, ~111km per degree)
        let radiusMeters = Int(max(span, 0.02) * 111000)

        // Random offset for sampling — fetches a random slice of incidents
        // so the heatmap represents a random sample, not just the most recent
        let randomOffset = Int.random(in: 0...2000)

        var components = URLComponents(string: endpoint.baseURL)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(
                name: "$where",
                value: "within_circle(\(endpoint.fieldMapping.geoColumn),\(lat),\(lon),\(radiusMeters)) AND \(endpoint.fieldMapping.datetime) > '\(since)'"
            ),
            URLQueryItem(name: "$limit", value: "200"),
            URLQueryItem(name: "$offset", value: "\(randomOffset)")
        ]
        if !appToken.isEmpty {
            queryItems.append(URLQueryItem(name: "$$app_token", value: appToken))
        }
        components?.queryItems = queryItems
        return components?.url
    }

    // MARK: - Parsing

    private func parseIncidents(from json: [[String: Any]], endpointName: String) -> [CrimeIncident] {
        switch endpointName {
        case "San Francisco":
            return parseSFIncidents(from: json)
        case "Oakland":
            return parseOaklandIncidents(from: json)
        case "Marin County":
            return parseMarinIncidents(from: json)
        default:
            return []
        }
    }

    private func parseSFIncidents(from json: [[String: Any]]) -> [CrimeIncident] {
        json.compactMap { item -> CrimeIncident? in
            guard let cat = item["incident_category"] as? String,
                  let latStr = item["latitude"] as? String, let lat = Double(latStr),
                  let lonStr = item["longitude"] as? String, let lon = Double(lonStr) else { return nil }
            guard lat.isFinite, lon.isFinite else { return nil }
            return CrimeIncident(
                category: cat,
                description: item["incident_description"] as? String ?? cat,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                date: Self.parseSODADate(item["incident_datetime"] as? String)
            )
        }
    }

    private func parseOaklandIncidents(from json: [[String: Any]]) -> [CrimeIncident] {
        json.compactMap { item -> CrimeIncident? in
            guard let crimeType = item["crimetype"] as? String,
                  let location = item["location_1"] as? [String: Any],
                  let coords = location["coordinates"] as? [Double],
                  coords.count >= 2 else { return nil }
            // CRITICAL: GeoJSON is [longitude, latitude]
            let lon = coords[0]
            let lat = coords[1]
            guard lat.isFinite, lon.isFinite else { return nil }
            return CrimeIncident(
                category: crimeType,
                description: item["description"] as? String ?? crimeType,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                date: Self.parseSODADate(item["datetime"] as? String)
            )
        }
    }

    private func parseMarinIncidents(from json: [[String: Any]]) -> [CrimeIncident] {
        json.compactMap { item -> CrimeIncident? in
            guard let crime = item["crime"] as? String,
                  let latStr = item["latitude"] as? String, let lat = Double(latStr),
                  let lonStr = item["longitude"] as? String, let lon = Double(lonStr) else { return nil }
            guard lat.isFinite, lon.isFinite else { return nil }
            return CrimeIncident(
                category: crime,
                description: item["crime_class"] as? String ?? crime,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                date: Self.parseSODADate(item["incident_date_time"] as? String)
            )
        }
    }

    // MARK: - Field validation

    /// Checks that all required fields are present in the first JSON item.
    /// Returns array of missing field names (empty if all present).
    private static func validateFields(_ json: [[String: Any]], required: [String]) -> [String] {
        guard let first = json.first else { return ["Empty response"] }
        return required.filter { first[$0] == nil }
    }

    // MARK: - Build hotspots from real incidents

    /// Clusters real incidents into Gaussian hotspots for smooth heatmap rendering.
    /// Moved from CrimeTileOverlay (deleted) during Mapbox migration.
    static func buildHotspots(from incidents: [CrimeIncident]) -> [CrimeHotspot] {
        guard !incidents.isEmpty else { return [] }

        // Finer clustering grid (0.002 deg ~ 200m) for granular hotspots
        let cellSize = 0.002
        var clusters: [String: (lat: Double, lon: Double, count: Int)] = [:]

        for incident in incidents {
            let lat = incident.coordinate.latitude
            let lon = incident.coordinate.longitude
            guard lat.isFinite, lon.isFinite else { continue }

            let row = Int(lat / cellSize)
            let col = Int(lon / cellSize)
            let key = "\(row)_\(col)"

            if var existing = clusters[key] {
                let n = Double(existing.count)
                existing.lat = (existing.lat * n + lat) / (n + 1)
                existing.lon = (existing.lon * n + lon) / (n + 1)
                existing.count += 1
                clusters[key] = existing
            } else {
                clusters[key] = (lat: lat, lon: lon, count: 1)
            }
        }

        let maxCount = clusters.values.map { $0.count }.max() ?? 1
        return clusters.values.map { cluster in
            let logWeight = log(1.0 + Double(cluster.count)) / log(1.0 + Double(maxCount))
            return CrimeHotspot(lat: cluster.lat, lon: cluster.lon, weight: logWeight)
        }
    }

    // MARK: - Scoring

    static func label(_ score: Int) -> String {
        switch score {
        case 80...100: return "Low Crime"
        case 60...79:  return "Moderate"
        case 40...59:  return "Above Average"
        default:       return "High Crime"
        }
    }

    /// Computes a safety score from the density grid's peak cell count.
    /// Higher density = lower score. Normalizes against a baseline of 50 incidents per cell.
    private static func densityScore(grid: DensityGrid?) -> Int {
        let peakDensity = Double(grid?.maxCount ?? 0)
        let normalized = min(peakDensity / 50.0, 1.0)
        let score = max(20, Int(100.0 - normalized * 80.0))
        return score
    }

    // MARK: - Grid building

    private static func buildGrid(from incidents: [CrimeIncident], lat: Double, lon: Double) -> DensityGrid {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        )
        return DensityGrid.build(from: incidents, region: region)
    }

    // MARK: - ZIP polygon crime density

    /// Counts incidents per census tract polygon and normalizes to 0.0-1.0 intensity.
    /// For tracts without real API data (outside SF/Oakland), falls back to Gaussian model.
    static func computeTractDensities(incidents: [CrimeIncident], tracts: [CensusTract]) -> [String: Double] {
        // Step 1: Count real incidents per tract
        var counts: [String: Int] = [:]
        for incident in incidents {
            let lat = incident.coordinate.latitude
            let lon = incident.coordinate.longitude
            guard lat.isFinite, lon.isFinite else { continue }

            for tract in tracts {
                let dLat = abs(lat - tract.center.latitude)
                let dLon = abs(lon - tract.center.longitude)
                guard dLat < 0.05, dLon < 0.05 else { continue }

                if Self.pointInPolygon(lat: lat, lon: lon, polygon: tract.polygon) {
                    counts[tract.id, default: 0] += 1
                    break
                }
            }
        }

        // Only populate tracts that have real incident data — no fake/estimated data
        guard let maxCount = counts.values.max(), maxCount > 0 else { return [:] }
        let logMax = log(1.0 + Double(maxCount))

        var densities: [String: Double] = [:]
        for (tractId, count) in counts {
            densities[tractId] = log(1.0 + Double(count)) / logMax
        }
        return densities
    }

    /// Ray-casting point-in-polygon test.
    private static func pointInPolygon(lat: Double, lon: Double, polygon: [CLLocationCoordinate2D]) -> Bool {
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let yi = polygon[i].latitude
            let xi = polygon[i].longitude
            let yj = polygon[j].latitude
            let xj = polygon[j].longitude

            if ((yi > lat) != (yj > lat)) &&
               (lon < (xj - xi) * (lat - yi) / (yj - yi) + xi) {
                inside = !inside
            }
            j = i
        }
        return inside
    }

    // MARK: - Bundled pre-computed tract densities

    /// Loads pre-computed per-tract crime densities for cities without live SODA APIs.
    /// Pre-computed offline via scripts/geocode_sanjose_crime.py — no runtime point-in-polygon.
    private static func loadBundledTractDensities() -> [String: Double] {
        var allDensities: [String: Double] = [:]

        // San Jose — pre-computed from 33K geocoded police calls
        if let url = Bundle.main.url(forResource: "sanjose_crime_densities.json", withExtension: "gz"),
           let compressed = try? Data(contentsOf: url),
           let decompressed = CensusTractData.gunzipPublic(compressed),
           let json = try? JSONSerialization.jsonObject(with: decompressed) as? [String: Any],
           let densities = json["densities"] as? [String: Double] {
            for (tractId, density) in densities {
                allDensities[tractId] = density
            }
            AppLogger.network.info("Crime: loaded \(densities.count) pre-computed tract densities (San Jose)")
        }

        return allDensities
    }

    // MARK: - Date parsing

    private static func parseSODADate(_ dateString: String?) -> Date {
        guard let dateString = dateString else { return Date() }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) { return date }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) { return date }
        // Try Socrata floating timestamp format: "2026-01-15T00:00:00.000"
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        df.locale = Locale(identifier: "en_US_POSIX")
        if let date = df.date(from: dateString) { return date }
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = df.date(from: dateString) { return date }
        return Date()
    }
}
