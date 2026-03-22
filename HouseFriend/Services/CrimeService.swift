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

// MARK: - CrimeService

class CrimeService: ObservableObject {
    @Published var incidents: [CrimeIncident] = []
    @Published var stats: CrimeStats = CrimeStats(score: 70, label: "Moderate", incidentCount: 0)
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var densityGrid: DensityGrid?
    @Published var recencyLabel: String = ""

    // TODO: Register at data.sfgov.org/profile/app_tokens and replace
    private static let appToken = ""

    /// One-time flag to clear stale crime cache from pre-real-data era
    private var hasClearedStaleCache = false

    // MARK: - Public API

    /// Fetches real crime incidents from all matching city SODA APIs for the given coordinate.
    func fetchNear(lat: Double, lon: Double) {
        // Clear stale cache from pre-real-data era on first fetch
        if !hasClearedStaleCache {
            hasClearedStaleCache = true
            ResponseCache.shared.clearLayer(.crime)
        }

        let matchingEndpoints = CityEndpoint.endpointsForRegion(lat: lat, lon: lon, span: 0.04)

        // No endpoints cover this area
        guard !matchingEndpoints.isEmpty else {
            DispatchQueue.main.async {
                self.errorMessage = "Crime data not available for this area"
                self.incidents = []
                self.stats = CrimeStats(score: 0, label: "No Data", incidentCount: 0)
                self.densityGrid = nil
                self.recencyLabel = ""
                self.isLoading = false
            }
            return
        }

        // Cache key based on which cities are covered (not viewport location)
        let cityNames = matchingEndpoints.map { $0.name }.sorted().joined(separator: "+")
        let cacheKey = "crime_cities_\(cityNames)"
        if let cachedData = ResponseCache.shared.get(key: cacheKey, layer: .crime) {
            if let json = try? JSONSerialization.jsonObject(with: cachedData) as? [String: Any],
               let allIncidents = json["incidents"] as? [[[String: Any]]],
               let endpointNames = json["endpoints"] as? [String] {
                var merged: [CrimeIncident] = []
                for (index, incidents) in allIncidents.enumerated() {
                    let name = index < endpointNames.count ? endpointNames[index] : ""
                    merged.append(contentsOf: parseIncidents(from: incidents, endpointName: name))
                }
                let grid = Self.buildGrid(from: merged, endpoints: matchingEndpoints)
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
            guard let url = Self.buildURL(endpoint: endpoint, since: ninetyDaysAgo) else {
                continue
            }

            group.enter()
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                defer { group.leave() }
                guard let self = self else { return }

                guard let data = data, error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                      !json.isEmpty else {
                    AppLogger.network.warning("Crime: \(endpoint.name) fetch failed or empty")
                    return
                }

                // Field validation (CRIME-06)
                let missing = Self.validateFields(json, required: endpoint.fieldMapping.requiredFields)
                if !missing.isEmpty {
                    AppLogger.network.error("Crime: \(endpoint.name) schema changed — missing \(missing.joined(separator: ", "))")
                    DispatchQueue.main.async {
                        self.errorMessage = "Crime data schema changed: missing \(missing.joined(separator: ", "))"
                    }
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

            let grid = Self.buildGrid(from: allIncidents, endpoints: matchingEndpoints)
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

            DispatchQueue.main.async {
                self.incidents = allIncidents
                self.densityGrid = grid
                self.stats = CrimeStats(score: score, label: Self.label(score), incidentCount: allIncidents.count)
                self.recencyLabel = "Based on incidents from last 90 days"
                self.errorMessage = nil
                self.isLoading = false
            }
        }
    }

    // MARK: - URL construction

    /// Builds a SODA query URL that fetches ALL incidents within the city's bounding box.
    /// Uses the full city bbox instead of within_circle so the heatmap covers the entire city smoothly.
    private static func buildURL(endpoint: CityEndpoint, since: String) -> URL? {
        let bb = endpoint.boundingBox
        var components = URLComponents(string: endpoint.baseURL)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(
                name: "$where",
                value: "\(endpoint.fieldMapping.datetime) > '\(since)' AND \(endpoint.fieldMapping.geoColumn) IS NOT NULL"
            ),
            URLQueryItem(name: "$limit", value: "50000"),
            URLQueryItem(name: "$order", value: "\(endpoint.fieldMapping.datetime) DESC")
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

    // MARK: - Field validation

    /// Checks that all required fields are present in the first JSON item.
    /// Returns array of missing field names (empty if all present).
    private static func validateFields(_ json: [[String: Any]], required: [String]) -> [String] {
        guard let first = json.first else { return ["Empty response"] }
        return required.filter { first[$0] == nil }
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

    /// Builds a density grid covering all matching city bounding boxes.
    /// Uses the union of all endpoint bounding boxes so the heatmap spans entire cities.
    private static func buildGrid(from incidents: [CrimeIncident], endpoints: [CityEndpoint]) -> DensityGrid {
        // Compute union of all city bounding boxes
        var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0
        for ep in endpoints {
            minLat = min(minLat, ep.boundingBox.swLat)
            maxLat = max(maxLat, ep.boundingBox.neLat)
            minLon = min(minLon, ep.boundingBox.swLon)
            maxLon = max(maxLon, ep.boundingBox.neLon)
        }
        // Add padding so edges fade off-screen
        let padding = 0.02
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) + padding * 2,
            longitudeDelta: (maxLon - minLon) + padding * 2
        )
        let region = MKCoordinateRegion(center: center, span: span)
        return DensityGrid.build(from: incidents, region: region)
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
