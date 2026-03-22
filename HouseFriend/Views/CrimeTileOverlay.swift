import MapKit
import UIKit

/// MKTileOverlay that renders crime heatmap tiles using Gaussian smoothing
/// over real incident coordinates. Each incident acts as a heat source that
/// bleeds into surrounding area, creating smooth organic heatmap contours
/// that follow where crimes naturally cluster (along streets, downtown, etc).
class CrimeTileOverlay: MKTileOverlay {

    // MARK: - Thread-safe hotspot data

    /// Hotspot derived from real crime data — coordinate + weight
    struct Hotspot {
        let lat: Double
        let lon: Double
        let weight: Double  // 0.0-1.0, based on incident count at this cluster
    }

    private let hotspotsLock = NSLock()
    private var _hotspots: [Hotspot] = []
    var hotspots: [Hotspot] {
        get { hotspotsLock.lock(); defer { hotspotsLock.unlock() }; return _hotspots }
        set { hotspotsLock.lock(); defer { hotspotsLock.unlock() }; _hotspots = newValue }
    }

    /// Gaussian radius in miles² — controls how far each hotspot bleeds
    /// Smaller = more granular detail, larger = smoother blending
    private let gaussianRadius: Double = 0.3

    // Degrees-to-miles rough conversion (Bay Area latitude)
    private let mpLat = 69.0
    private let mpLon = 53.0

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
    /// Groups nearby incidents (within ~0.005°) and uses the cluster count as weight.
    static func buildHotspots(from incidents: [CrimeIncident]) -> [Hotspot] {
        guard !incidents.isEmpty else { return [] }

        // Cluster incidents into grid cells (0.005° ≈ 500m)
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
                // Running average of coordinates + count
                let n = Double(existing.count)
                existing.lat = (existing.lat * n + lat) / (n + 1)
                existing.lon = (existing.lon * n + lon) / (n + 1)
                existing.count += 1
                clusters[key] = existing
            } else {
                clusters[key] = (lat: lat, lon: lon, count: 1)
            }
        }

        // Normalize weights: max cluster count → 1.0
        let maxCount = clusters.values.map { $0.count }.max() ?? 1

        return clusters.values.map { cluster in
            // Log scale weight: prevents a few high-count clusters from dominating
            // log(1+count)/log(1+max) gives 0.0-1.0 range with diminishing returns
            let logWeight = log(1.0 + Double(cluster.count)) / log(1.0 + Double(maxCount))
            return Hotspot(
                lat: cluster.lat,
                lon: cluster.lon,
                weight: logWeight
            )
        }
    }

    // MARK: - Tile generation

    func renderTile(z: Int, x: Int, y: Int) -> Data? {
        let (minLat, maxLat, minLon, maxLon) = Self.tileBounds(z: z, x: x, y: y)

        // Skip tiles clearly outside Bay Area
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
                    guard v > 0.0 else { continue }
                    let (r, g, b) = Self.crimeRGB(v)
                    let alpha = min(0.72, max(0.38, v * 0.82))
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

    // MARK: - Gaussian crime intensity

    /// Computes crime intensity at a coordinate using Gaussian smoothing over real hotspots.
    /// Each hotspot contributes exp(-dist²/radius²) * weight. Returns 0.0 when no hotspots loaded.
    func crimeValue(lat: Double, lon: Double) -> Double {
        let spots = hotspots
        guard !spots.isEmpty else { return 0.0 }

        var value = 0.0
        let r2 = gaussianRadius * gaussianRadius

        for h in spots {
            let dLat = (lat - h.lat) * mpLat
            let dLon = (lon - h.lon) * mpLon
            let dist2 = dLat * dLat + dLon * dLon
            // Skip hotspots too far away (> 4x radius = negligible contribution)
            guard dist2 < r2 * 16 else { continue }
            value += h.weight * exp(-dist2 / r2)
        }

        // Apply baseline + scale to get visible range without saturation
        // Raw value can exceed 1.0 in dense areas; compress with diminishing returns
        let compressed = 1.0 - exp(-value * 2.0)  // asymptotic approach to 1.0
        guard compressed > 0.05 else { return 0.0 }  // cut off very faint areas
        return compressed
    }

    static func crimeRGB(_ v: Double) -> (UInt8, UInt8, UInt8) {
        if v >= 0.72 { return (191,  13,  13) }
        if v >= 0.55 { return (235,  64,  20) }
        if v >= 0.40 { return (250, 133,  38) }
        if v >= 0.28 { return (254, 184,  89) }
        if v >= 0.18 { return (255, 219, 153) }
        return               (255, 238, 200)
    }
}
