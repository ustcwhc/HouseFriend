import MapKit
import UIKit

/// MKTileOverlay that renders crime heatmap tiles using Gaussian smoothing
/// over real incident coordinates + Gaussian fallback for uncovered areas.
/// Gas/glow effect on dark map — red-to-transparent gradient like SafeMap.io.
class CrimeTileOverlay: MKTileOverlay {

    // MARK: - Thread-safe hotspot data

    /// Hotspot derived from real crime data — coordinate + weight
    struct Hotspot {
        let lat: Double
        let lon: Double
        let weight: Double  // 0.0-1.0
    }

    private let hotspotsLock = NSLock()
    private var _hotspots: [Hotspot] = []
    var hotspots: [Hotspot] {
        get { hotspotsLock.lock(); defer { hotspotsLock.unlock() }; return _hotspots }
        set { hotspotsLock.lock(); defer { hotspotsLock.unlock() }; _hotspots = newValue }
    }

    /// Gaussian radius in miles² — controls how far each hotspot bleeds
    private let gaussianRadius: Double = 0.4

    // Degrees-to-miles rough conversion (Bay Area latitude)
    private let mpLat = 69.0
    private let mpLon = 53.0

    // MARK: - Gaussian fallback hotspots (all Bay Area)

    /// Original 21 hotspots + 11 safe zones covering the entire Bay Area.
    /// Used for areas without real API data (San Jose, Fremont, etc.)
    private static let fallbackHotspots: [(Double, Double, Double, Double)] = [
        (37.812, -122.285, 1.00, 2.5), (37.928, -122.362, 0.95, 2.0),
        (37.782, -122.415, 0.90, 1.8), (37.770, -122.220, 0.88, 2.5),
        (38.105, -122.255, 0.82, 2.0), (37.343, -121.875, 0.82, 3.0),
        (37.727, -122.390, 0.80, 2.0), (37.998, -121.808, 0.78, 2.0),
        (37.670, -122.082, 0.72, 2.0), (37.962, -122.343, 0.70, 1.8),
        (37.338, -121.888, 0.68, 2.5), (38.021, -121.878, 0.65, 1.8),
        (37.748, -122.198, 0.62, 2.0), (37.758, -122.415, 0.60, 1.8),
        (37.538, -121.975, 0.50, 2.5), (37.985, -122.058, 0.48, 2.0),
        (37.976, -122.518, 0.45, 1.8), (37.270, -121.868, 0.45, 2.5),
        (37.630, -121.888, 0.45, 2.0), (37.432, -121.902, 0.42, 2.0),
        (37.698, -122.469, 0.38, 1.8),
    ]
    private static let fallbackSafeZones: [(Double, Double, Double, Double)] = [
        (37.322, -122.040, 0.50, 4.0), (37.265, -122.030, 0.55, 3.5),
        (37.440, -122.165, 0.60, 4.5), (37.378, -122.100, 0.55, 3.5),
        (37.863, -122.248, 0.55, 2.5), (37.882, -122.165, 0.60, 4.0),
        (37.822, -121.978, 0.58, 4.0), (37.662, -121.878, 0.58, 3.5),
        (37.895, -122.512, 0.60, 5.0), (37.568, -122.320, 0.45, 4.0),
        (37.928, -122.108, 0.48, 4.0),
    ]

    override init(urlTemplate: String? = nil) {
        super.init(urlTemplate: nil)
        self.tileSize = CGSize(width: 256, height: 256)
        self.minimumZ = 7
        self.maximumZ = 17
        self.canReplaceMapContent = false
    }

    override func loadTile(at path: MKTileOverlayPath,
                           result: @escaping (Data?, Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { result(nil, nil); return }
            let data = self.renderTile(z: path.z, x: path.x, y: path.y)
            result(data, nil)
        }
    }

    // MARK: - Build hotspots from real incidents

    /// Clusters real incidents into Gaussian hotspots for smooth rendering.
    static func buildHotspots(from incidents: [CrimeIncident]) -> [Hotspot] {
        guard !incidents.isEmpty else { return [] }

        let cellSize = 0.005
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
            return Hotspot(lat: cluster.lat, lon: cluster.lon, weight: logWeight)
        }
    }

    // MARK: - Tile generation (gas/glow effect)

    func renderTile(z: Int, x: Int, y: Int) -> Data? {
        let (minLat, maxLat, minLon, maxLon) = Self.tileBounds(z: z, x: x, y: y)

        guard maxLat > 36.8 && minLat < 38.9 &&
              maxLon > -123.5 && minLon < -121.0 else { return nil }

        let size = z >= 14 ? 128 : z >= 11 ? 96 : 64
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            for row in 0..<size {
                for col in 0..<size {
                    let lat = maxLat - Double(row) / Double(size) * (maxLat - minLat)
                    let lon = minLon + Double(col) / Double(size) * (maxLon - minLon)
                    let v = crimeValue(lat: lat, lon: lon)
                    guard v > 0.02 else { continue }

                    // Gas/glow color: red-orange-yellow with soft alpha for glow effect
                    let (r, g, b) = Self.glowRGB(v)
                    let alpha = min(0.85, v * 0.9)  // Softer alpha for gas-like transparency
                    cg.setFillColor(red:   CGFloat(r) / 255,
                                    green: CGFloat(g) / 255,
                                    blue:  CGFloat(b) / 255,
                                    alpha: CGFloat(alpha))
                    cg.fill(CGRect(x: col, y: row, width: 1, height: 1))
                }
            }
        }
        return image.pngData()
    }

    // MARK: - Web Mercator tile -> lat/lon

    static func tileBounds(z: Int, x: Int, y: Int)
        -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        let n = pow(2.0, Double(z))
        let lonMin = Double(x)     / n * 360.0 - 180.0
        let lonMax = Double(x + 1) / n * 360.0 - 180.0
        let latMaxRad = atan(sinh(.pi * (1.0 - 2.0 * Double(y)     / n)))
        let latMinRad = atan(sinh(.pi * (1.0 - 2.0 * Double(y + 1) / n)))
        return (latMinRad * 180 / .pi, latMaxRad * 180 / .pi, lonMin, lonMax)
    }

    // MARK: - Gaussian crime intensity (real hotspots + fallback)

    /// Computes crime intensity combining real hotspots (where available) with
    /// Gaussian fallback for the rest of the Bay Area.
    func crimeValue(lat: Double, lon: Double) -> Double {
        // Check if point is in an API-covered city
        let isCovered = CityEndpoint.endpoints.contains { ep in
            let bb = ep.boundingBox
            return lat >= bb.swLat && lat <= bb.neLat && lon >= bb.swLon && lon <= bb.neLon
        }

        if isCovered {
            // Use real hotspots from API data
            return realHotspotValue(lat: lat, lon: lon)
        } else {
            // Use Gaussian fallback for uncovered areas
            return fallbackValue(lat: lat, lon: lon)
        }
    }

    /// Intensity from real incident hotspots
    private func realHotspotValue(lat: Double, lon: Double) -> Double {
        let spots = hotspots
        guard !spots.isEmpty else { return 0.0 }

        var value = 0.0
        let r2 = gaussianRadius * gaussianRadius

        for h in spots {
            let dLat = (lat - h.lat) * mpLat
            let dLon = (lon - h.lon) * mpLon
            let dist2 = dLat * dLat + dLon * dLon
            guard dist2 < r2 * 16 else { continue }
            value += h.weight * exp(-dist2 / r2)
        }

        let compressed = 1.0 - exp(-value * 2.5)
        guard compressed > 0.03 else { return 0.0 }
        return compressed
    }

    /// Intensity from fallback Gaussian model (all Bay Area)
    private func fallbackValue(lat: Double, lon: Double) -> Double {
        var v = 0.15
        for h in Self.fallbackHotspots {
            let d2 = pow((lat - h.0) * mpLat, 2) + pow((lon - h.1) * mpLon, 2)
            v += h.2 * exp(-d2 / (h.3 * h.3))
        }
        for s in Self.fallbackSafeZones {
            let d2 = pow((lat - s.0) * mpLat, 2) + pow((lon - s.1) * mpLon, 2)
            v -= s.2 * exp(-d2 / (s.3 * s.3))
        }
        // Shift down so low-crime areas are more transparent
        let shifted = max(0.0, v - 0.20)
        return min(1.0, shifted)
    }

    // MARK: - Gas/glow color gradient (for dark map background)

    /// Warm glow colors: transparent → yellow → orange → red → bright red
    /// Designed to look like a gas/thermal leak on a dark map
    static func glowRGB(_ v: Double) -> (UInt8, UInt8, UInt8) {
        if v >= 0.75 { return (255,  30,  30) }   // Bright red — danger zones
        if v >= 0.55 { return (255,  60,  15) }   // Red-orange
        if v >= 0.40 { return (255, 100,  10) }   // Orange
        if v >= 0.25 { return (255, 150,  30) }   // Warm orange
        if v >= 0.12 { return (255, 190,  50) }   // Yellow-orange
        return               (255, 220, 100)       // Warm yellow — faint glow
    }
}
