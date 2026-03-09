import SwiftUI
import Foundation
import MapKit

// MARK: - Models

struct NoiseZone: Identifiable {
    let id = UUID()
    let polygon: [CLLocationCoordinate2D]
    let dbLevel: Int
}

struct NoiseRoad: Identifiable {
    let id: UUID
    let coordinates: [CLLocationCoordinate2D]
    let highwayType: String
    let name: String

    var dbLevel: Int {
        switch highwayType {
        case "motorway", "motorway_link":       return 78
        case "trunk", "trunk_link":             return 74
        case "primary", "primary_link":         return 68
        case "secondary", "secondary_link":     return 63
        case "tertiary", "tertiary_link":       return 58
        case "residential", "living_street":    return 52
        case "service", "unclassified":         return 47
        default:                                return 50
        }
    }

    var lineWidth: CGFloat {
        switch highwayType {
        case "motorway", "trunk":       return 5
        case "primary":                 return 4
        case "secondary":               return 3
        case "tertiary":                return 2.5
        case "residential":             return 2
        default:                        return 1.5
        }
    }
}

// MARK: - Service

class NoiseService: ObservableObject {
    @Published var roads:    [NoiseRoad] = []
    @Published var zones:    [NoiseZone] = []   // kept for API compat
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var needsZoomIn = false          // true when span too large

    private var lastFetchedRegion: MKCoordinateRegion?
    private let maxSpanForDetail: Double = 0.25   // ~17 miles — fetch residential
    private let maxSpanForMajor:  Double = 1.2    // ~80 miles — fetch only motorway/primary
    private var currentTask: URLSessionDataTask?   // B2: cancellable in-flight request

    /// Cancel any pending Overpass fetch (called by HFMapView when user starts panning)
    func cancelFetch() {
        currentTask?.cancel()
        currentTask = nil
        DispatchQueue.main.async { self.isLoading = false }
    }

    // MARK: - Public API

    /// Call this whenever the noise layer is active and map camera changes
    func fetchForRegion(_ region: MKCoordinateRegion) {
        let span = region.span.latitudeDelta

        // Too zoomed out for any useful road data
        if span > maxSpanForMajor {
            DispatchQueue.main.async {
                self.needsZoomIn = true
                self.roads = []
            }
            return
        }

        // Avoid redundant refetches for small pans
        if let last = lastFetchedRegion,
           abs(last.center.latitude  - region.center.latitude)  < last.span.latitudeDelta  * 0.2,
           abs(last.center.longitude - region.center.longitude) < last.span.longitudeDelta * 0.2,
           abs(last.span.latitudeDelta - span) < 0.02 {
            return
        }

        lastFetchedRegion = region
        needsZoomIn = false
        isLoading = true
        errorMessage = nil

        let south = region.center.latitude  - region.span.latitudeDelta  / 2
        let north = region.center.latitude  + region.span.latitudeDelta  / 2
        let west  = region.center.longitude - region.span.longitudeDelta / 2
        let east  = region.center.longitude + region.span.longitudeDelta / 2

        // Filter: when zoomed out, only fetch major roads to keep response small
        let highwayFilter: String
        if span > maxSpanForDetail {
            highwayFilter = "motorway|trunk|primary"
        } else {
            highwayFilter = "motorway|trunk|primary|secondary|tertiary|residential|service|living_street"
        }

        let query = """
            [out:json][timeout:25];
            way["highway"~"\(highwayFilter)"](\(south),\(west),\(north),\(east));
            out body;
            >;
            out skel qt;
            """

        fetchFromOverpass(query: query)
    }

    /// Legacy — still works, fetches predefined South Bay roads
    func fetch() {
        // Seed with static Bay Area major roads so the layer shows on launch
        // (dynamic per-region roads overlay these when zoomed in)
        zones = []   // no polygon zones anymore
        fetchForRegion(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.650, longitude: -122.150),
            span: MKCoordinateSpan(latitudeDelta: 0.80, longitudeDelta: 0.80)
        ))
    }

    // MARK: - Network

    private func fetchFromOverpass(query: String) {
        // Try primary, fall back to mirror
        let mirrors = [
            "https://overpass-api.de/api/interpreter",
            "https://overpass.kumi.systems/api/interpreter",
        ]
        fetchFrom(mirrors: mirrors, query: query)
    }

    private func fetchFrom(mirrors: [String], query: String) {
        guard let urlStr = mirrors.first, let url = URL(string: urlStr) else {
            DispatchQueue.main.async { self.isLoading = false }
            return
        }

        var request = URLRequest(url: url, timeoutInterval: 28)
        request.httpMethod = "POST"
        let body = "data=" + (query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        request.httpBody = body.data(using: .utf8)

        currentTask?.cancel()
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if let error = error {
                AppLogger.network.warning("Noise fetch failed (\(urlStr)): \(error.localizedDescription)")
                let remaining = Array(mirrors.dropFirst())
                if !remaining.isEmpty {
                    self.fetchFrom(mirrors: remaining, query: query)
                } else {
                    AppLogger.network.error("Noise: all Overpass mirrors exhausted")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Network error: \(error.localizedDescription)"
                    }
                }
                return
            }

            guard let data else {
                AppLogger.network.warning("Noise: empty response from \(urlStr)")
                DispatchQueue.main.async { self.isLoading = false }
                return
            }

            let parsed = Self.parseOSMResponse(data)
            AppLogger.network.info("Noise: parsed \(parsed.count) roads")
            DispatchQueue.main.async {
                self.roads = parsed
                self.isLoading = false
            }
        }
        currentTask = task
        task.resume()
    }

    // MARK: - Parser

    static func parseOSMResponse(_ data: Data) -> [NoiseRoad] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let elements = json["elements"] as? [[String: Any]] else { return [] }

        // Build node lookup
        var nodeMap: [Int64: CLLocationCoordinate2D] = [:]
        for el in elements where (el["type"] as? String) == "node" {
            if let id  = el["id"]  as? Int64,
               let lat = el["lat"] as? Double,
               let lon = el["lon"] as? Double {
                nodeMap[id] = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            } else if let id  = el["id"]  as? Int,
                      let lat = el["lat"] as? Double,
                      let lon = el["lon"] as? Double {
                nodeMap[Int64(id)] = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }

        var roads: [NoiseRoad] = []
        for el in elements where (el["type"] as? String) == "way" {
            guard let tags = el["tags"] as? [String: String],
                  let highway = tags["highway"],
                  let nodeIds = el["nodes"] as? [Int] else { continue }

            let coords = nodeIds.compactMap { nodeMap[Int64($0)] }
            guard coords.count >= 2 else { continue }

            roads.append(NoiseRoad(
                id: UUID(),
                coordinates: coords,
                highwayType: highway,
                name: tags["name"] ?? ""
            ))
        }
        return roads
    }

    // MARK: - Color helper

    static func color(for db: Int) -> Color {
        switch db {
        case ..<50:   return Color(red: 0.4, green: 0.85, blue: 0.4)
        case 50..<55: return Color(red: 1.0, green: 0.92, blue: 0.1)
        case 55..<60: return Color(red: 1.0, green: 0.72, blue: 0.0)
        case 60..<65: return Color(red: 1.0, green: 0.45, blue: 0.0)
        case 65..<70: return Color(red: 0.92, green: 0.1, blue: 0.3)
        case 70..<78: return Color(red: 0.60, green: 0.0, blue: 0.72)
        default:      return Color(red: 0.28, green: 0.0, blue: 0.50)
        }
    }

    static func colorTuple(for db: Int) -> (r: Double, g: Double, b: Double) {
        switch db {
        case ..<50:   return (0.4, 0.85, 0.4)
        case 50..<55: return (1.0, 0.92, 0.1)
        case 55..<60: return (1.0, 0.72, 0.0)
        case 60..<65: return (1.0, 0.45, 0.0)
        case 65..<70: return (0.92, 0.1, 0.3)
        case 70..<78: return (0.60, 0.0, 0.72)
        default:      return (0.28, 0.0, 0.50)
        }
    }
}
