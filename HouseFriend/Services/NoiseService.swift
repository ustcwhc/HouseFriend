import SwiftUI
import Foundation
import Compression
import MapKit

// MARK: - Models

struct NoiseZone: Identifiable {
    let id = UUID()
    let polygon: [CLLocationCoordinate2D]
    let dbLevel: Int
}

struct NoiseRoad: Identifiable {
    let id: UUID
    let wayId: Int64?           // OSM way ID for deduplication (nil for legacy)
    let coordinates: [CLLocationCoordinate2D]
    let highwayType: String
    let name: String

    var dbLevel: Int {
        switch highwayType {
        case "motorway", "motorway_link":               return 78
        case "trunk", "trunk_link":                     return 74
        case "primary", "primary_link":                 return 68
        case "secondary", "secondary_link":             return 63
        case "tertiary", "tertiary_link":               return 58
        case "residential", "living_street":            return 52
        case "service", "unclassified":                 return 47
        case "railway_rail":                            return 75
        case "railway_light_rail", "railway_subway":    return 70
        default:                                        return 50
        }
    }

    var lineWidth: CGFloat {
        switch highwayType {
        case "motorway", "trunk":                       return 5
        case "primary":                                 return 4
        case "railway_rail":                            return 4
        case "railway_light_rail", "railway_subway":    return 3.5
        case "secondary":                               return 3
        case "tertiary":                                return 2.5
        case "residential":                             return 2
        default:                                        return 1.5
        }
    }

    /// True for railways (rendered with dashed pattern)
    var isRailway: Bool { highwayType.hasPrefix("railway_") }
}

// MARK: - Service

class NoiseService: ObservableObject {
    @Published var roads:    [NoiseRoad] = []
    @Published var zones:    [NoiseZone] = []   // kept for API compat
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var needsZoomIn = false

    /// Static bundled roads (loaded once from bayarea_roads.json)
    private var staticRoads: [NoiseRoad] = []
    private var staticLoaded = false

    private var lastFetchedRegion: MKCoordinateRegion?
    private let maxSpanForDetail: Double = 0.08   // ~5.5 mi — fetch secondary/residential
    private let maxSpanForMajor:  Double = 1.2    // ~80 mi — beyond this, static only
    private var currentTask: URLSessionDataTask?

    // MARK: - Init

    init() {
        loadStaticRoads()
    }

    /// Cancel any pending Overpass fetch
    func cancelFetch() {
        currentTask?.cancel()
        currentTask = nil
        DispatchQueue.main.async { self.isLoading = false }
    }

    // MARK: - Static data (instant)

    private func loadStaticRoads() {
        guard !staticLoaded else { return }
        staticLoaded = true

        // Load gzip-compressed bundle (514 KB) with fallback to uncompressed
        let data: Data
        if let gzURL = Bundle.main.url(forResource: "bayarea_roads.json", withExtension: "gz"),
           let compressed = try? Data(contentsOf: gzURL),
           let decompressed = Self.gunzip(compressed) {
            data = decompressed
        } else if let jsonURL = Bundle.main.url(forResource: "bayarea_roads", withExtension: "json"),
                  let raw = try? Data(contentsOf: jsonURL) {
            data = raw
        } else {
            AppLogger.network.warning("Noise: bayarea_roads data not found in bundle")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let parsed = Self.parseBundledJSON(data)
            AppLogger.network.info("Noise: loaded \(parsed.count) static roads from bundle")
            DispatchQueue.main.async {
                self?.staticRoads = parsed
                // Show static roads immediately if no dynamic roads loaded yet
                if self?.roads.isEmpty == true {
                    self?.roads = parsed
                }
            }
        }
    }

    // MARK: - Public API

    /// Called when noise layer is activated or map camera changes
    func fetchForRegion(_ region: MKCoordinateRegion) {
        let span = region.span.latitudeDelta

        // Very zoomed out: freeways aren't even visible, skip rendering entirely
        if span > maxSpanForMajor {
            needsZoomIn = true
            roads = []
            isLoading = false
            return
        }

        needsZoomIn = false

        // Filter static roads to visible region
        let visibleStatic = filterRoadsToRegion(staticRoads, region: region)

        if span > maxSpanForDetail {
            // Zoomed out: show only static major roads (instant, no network)
            roads = visibleStatic
            isLoading = false
            return
        }

        // Zoomed in: show static roads immediately, then fetch detail from Overpass
        if roads.isEmpty || !roadsOverlapRegion(region) {
            roads = visibleStatic
        }

        // Avoid redundant refetches for small pans
        if let last = lastFetchedRegion,
           abs(last.center.latitude  - region.center.latitude)  < last.span.latitudeDelta  * 0.2,
           abs(last.center.longitude - region.center.longitude) < last.span.longitudeDelta * 0.2,
           abs(last.span.latitudeDelta - span) < 0.01 {
            return
        }

        lastFetchedRegion = region
        isLoading = true
        errorMessage = nil

        let south = region.center.latitude  - region.span.latitudeDelta  / 2
        let north = region.center.latitude  + region.span.latitudeDelta  / 2
        let west  = region.center.longitude - region.span.longitudeDelta / 2
        let east  = region.center.longitude + region.span.longitudeDelta / 2

        let query = """
            [out:json][timeout:25];
            (
              way["highway"~"motorway|trunk|primary|secondary|tertiary|residential|service|living_street"](\(south),\(west),\(north),\(east));
              way["railway"~"rail|light_rail|subway"](\(south),\(west),\(north),\(east));
            );
            out body;
            >;
            out skel qt;
            """

        fetchFromOverpass(query: query, staticFallback: visibleStatic)
    }

    /// Legacy entry point — loads static roads instantly
    func fetch() {
        zones = []
        // Static roads are already loaded in init; just publish them
        if !staticRoads.isEmpty {
            roads = staticRoads
        }
    }

    // MARK: - Region helpers

    private func filterRoadsToRegion(_ allRoads: [NoiseRoad], region: MKCoordinateRegion) -> [NoiseRoad] {
        let south = region.center.latitude  - region.span.latitudeDelta  / 2
        let north = region.center.latitude  + region.span.latitudeDelta  / 2
        let west  = region.center.longitude - region.span.longitudeDelta / 2
        let east  = region.center.longitude + region.span.longitudeDelta / 2

        return allRoads.filter { road in
            road.coordinates.contains { c in
                c.latitude >= south && c.latitude <= north &&
                c.longitude >= west && c.longitude <= east
            }
        }
    }

    private func roadsOverlapRegion(_ region: MKCoordinateRegion) -> Bool {
        let south = region.center.latitude  - region.span.latitudeDelta  / 2
        let north = region.center.latitude  + region.span.latitudeDelta  / 2
        let west  = region.center.longitude - region.span.longitudeDelta / 2
        let east  = region.center.longitude + region.span.longitudeDelta / 2

        return roads.contains { road in
            road.coordinates.contains { c in
                c.latitude >= south && c.latitude <= north &&
                c.longitude >= west && c.longitude <= east
            }
        }
    }

    // MARK: - Network

    private func fetchFromOverpass(query: String, staticFallback: [NoiseRoad]) {
        let mirrors = [
            "https://overpass-api.de/api/interpreter",
            "https://overpass.kumi.systems/api/interpreter",
        ]
        fetchFrom(mirrors: mirrors, query: query, staticFallback: staticFallback)
    }

    private func fetchFrom(mirrors: [String], query: String, staticFallback: [NoiseRoad]) {
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
                if (error as NSError).code == NSURLErrorCancelled { return }
                AppLogger.network.warning("Noise fetch failed (\(urlStr)): \(error.localizedDescription)")
                let remaining = Array(mirrors.dropFirst())
                if !remaining.isEmpty {
                    self.fetchFrom(mirrors: remaining, query: query, staticFallback: staticFallback)
                } else {
                    AppLogger.network.error("Noise: all Overpass mirrors exhausted, using static data")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        // Keep showing static roads on network failure
                        if self.roads.isEmpty {
                            self.roads = staticFallback
                        }
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
            AppLogger.network.info("Noise: fetched \(parsed.count) detail roads from Overpass")
            DispatchQueue.main.async {
                // Merge: Overpass detail + static roads not already covered
                let overpassIds = Set(parsed.compactMap { $0.wayId })
                let extraStatic = staticFallback.filter { road in
                    guard let wid = road.wayId else { return true }
                    return !overpassIds.contains(wid)
                }
                self.roads = parsed + extraStatic
                self.isLoading = false
            }
        }
        currentTask = task
        task.resume()
    }

    // MARK: - Parsers

    /// Parse bundled bayarea_roads.json (compact format)
    static func parseBundledJSON(_ data: Data) -> [NoiseRoad] {
        guard let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return entries.compactMap { entry -> NoiseRoad? in
            guard let wayId = entry["wayId"] as? Int64 ?? (entry["wayId"] as? Int).map({ Int64($0) }),
                  let type = entry["type"] as? String,
                  let coords = entry["coords"] as? [[Double]],
                  coords.count >= 2 else { return nil }

            let clCoords = coords.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
            return NoiseRoad(
                id: UUID(),
                wayId: wayId,
                coordinates: clCoords,
                highwayType: type,
                name: entry["name"] as? String ?? ""
            )
        }
    }

    /// Parse Overpass API OSM response
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
                  let nodeIds = el["nodes"] as? [Int] else { continue }

            let highway = tags["highway"]
            let railway = tags["railway"]
            guard highway != nil || railway != nil else { continue }

            let roadType: String
            if let hw = highway {
                roadType = hw
            } else if let rw = railway {
                roadType = "railway_\(rw)"
            } else { continue }

            let wayId: Int64
            if let wid = el["id"] as? Int64 {
                wayId = wid
            } else if let wid = el["id"] as? Int {
                wayId = Int64(wid)
            } else { continue }

            let coords = nodeIds.compactMap { nodeMap[Int64($0)] }
            guard coords.count >= 2 else { continue }

            roads.append(NoiseRoad(
                id: UUID(),
                wayId: wayId,
                coordinates: coords,
                highwayType: roadType,
                name: tags["name"] ?? ""
            ))
        }
        return roads
    }

    // MARK: - Gzip decompression

    /// Decompress gzip data using the Compression framework.
    private static func gunzip(_ data: Data) -> Data? {
        guard data.count > 18 else { return nil }
        // Skip gzip header to get raw deflate stream
        var headerLen = 10
        let flags = data[3]
        if flags & 0x04 != 0 { // FEXTRA
            guard data.count > headerLen + 2 else { return nil }
            headerLen += 2 + Int(data[headerLen]) + Int(data[headerLen + 1]) << 8
        }
        if flags & 0x08 != 0 { // FNAME
            while headerLen < data.count && data[headerLen] != 0 { headerLen += 1 }
            headerLen += 1
        }
        if flags & 0x10 != 0 { // FCOMMENT
            while headerLen < data.count && data[headerLen] != 0 { headerLen += 1 }
            headerLen += 1
        }
        if flags & 0x02 != 0 { headerLen += 2 } // FHCRC

        let deflated = data.subdata(in: headerLen..<(data.count - 8))
        let bufferSize = 8 * 1024 * 1024 // 8 MB
        var output = Data(count: bufferSize)
        let decoded = output.withUnsafeMutableBytes { outPtr -> Int in
            deflated.withUnsafeBytes { inPtr -> Int in
                let out = outPtr.bindMemory(to: UInt8.self)
                let inp = inPtr.bindMemory(to: UInt8.self)
                return compression_decode_buffer(
                    out.baseAddress!, bufferSize,
                    inp.baseAddress!, deflated.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        guard decoded > 0 else { return nil }
        output.count = decoded
        return output
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
