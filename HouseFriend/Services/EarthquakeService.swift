import Foundation
import MapKit

struct EarthquakeEvent: Identifiable {
    let id = UUID()
    let magnitude: Double
    let place: String
    let coordinate: CLLocationCoordinate2D
    let date: Date
}

class EarthquakeService: ObservableObject {
    @Published var events: [EarthquakeEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // USGS Earthquake API - past 30 days, magnitude >= 2.5, Bay Area bounding box
    private var urlString: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let startDate = Date().addingTimeInterval(-30 * 86400)
        let start = formatter.string(from: startDate)
        return "https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson&starttime=\(start)&minmagnitude=2.5&minlatitude=36.8&maxlatitude=38.0&minlongitude=-122.6&maxlongitude=-121.2&orderby=magnitude"
    }

    func fetch() {
        isLoading = true
        errorMessage = nil

        // Check cache first
        let cacheKey = ResponseCache.cacheKey(layer: .earthquake)
        if let cachedData = ResponseCache.shared.get(key: cacheKey, layer: .earthquake) {
            do {
                let decoded = try JSONDecoder().decode(USGSResponse.self, from: cachedData)
                let events = Self.parseEvents(from: decoded)
                AppLogger.network.info("Earthquake: loaded \(events.count) events from cache")
                DispatchQueue.main.async {
                    self.events = events
                    self.isLoading = false
                }
                return
            } catch {
                AppLogger.network.warning("Earthquake: cache decode failed, fetching from network")
            }
        }

        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            defer { DispatchQueue.main.async { self?.isLoading = false } }
            guard let data = data, error == nil else {
                AppLogger.network.error("Earthquake fetch failed: \(error?.localizedDescription ?? "no data")")
                DispatchQueue.main.async { self?.errorMessage = "Earthquake data unavailable" }
                return
            }
            do {
                let decoded = try JSONDecoder().decode(USGSResponse.self, from: data)
                let events = Self.parseEvents(from: decoded)
                ResponseCache.shared.set(data: data, key: cacheKey, layer: .earthquake)
                AppLogger.network.info("Earthquake: fetched \(events.count) events from network")
                DispatchQueue.main.async { self?.events = events }
            } catch {
                AppLogger.network.error("Earthquake parse error: \(error.localizedDescription)")
                DispatchQueue.main.async { self?.errorMessage = "Failed to parse earthquake data" }
            }
        }.resume()
    }

    // MARK: - Parsing

    private static func parseEvents(from decoded: USGSResponse) -> [EarthquakeEvent] {
        decoded.features.compactMap { feature -> EarthquakeEvent? in
            guard let coords = feature.geometry.coordinates, coords.count >= 2 else { return nil }
            return EarthquakeEvent(
                magnitude: feature.properties.mag ?? 0,
                place: feature.properties.place ?? "Unknown",
                coordinate: CLLocationCoordinate2D(latitude: coords[1], longitude: coords[0]),
                date: Date(timeIntervalSince1970: Double(feature.properties.time) / 1000.0)
            )
        }
    }

    // MARK: - Codable models
    struct USGSResponse: Decodable {
        let features: [Feature]
    }
    struct Feature: Decodable {
        let geometry: Geometry
        let properties: Properties
    }
    struct Geometry: Decodable {
        let coordinates: [Double]?
    }
    struct Properties: Decodable {
        let mag: Double?
        let place: String?
        let time: Int
    }
}
