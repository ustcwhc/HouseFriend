import MapKit
import UIKit

/// MKTileOverlay that renders crime heatmap tiles.
/// Tiles are generated on a background thread and cached by MapKit automatically.
/// Because tiles live in MapKit's coordinate space, the overlay follows
/// map panning/zooming perfectly with zero lag.
class CrimeTileOverlay: MKTileOverlay {

    override init(urlTemplate: String? = nil) {
        super.init(urlTemplate: nil)
        self.tileSize = CGSize(width: 256, height: 256)
        self.minimumZ = 7
        self.maximumZ = 17
        self.canReplaceMapContent = false   // keep base map visible underneath
    }

    override func loadTile(at path: MKTileOverlayPath,
                           result: @escaping (Data?, Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let data = Self.renderTile(z: path.z, x: path.x, y: path.y)
            result(data, nil)
        }
    }

    // MARK: - Tile generation

    static func renderTile(z: Int, x: Int, y: Int) -> Data? {
        let (minLat, maxLat, minLon, maxLon) = tileBounds(z: z, x: x, y: y)

        // Skip tiles clearly outside Bay Area
        guard maxLat > 36.8 && minLat < 38.9 &&
              maxLon > -123.5 && minLon < -121.0 else { return nil }

        // Scale resolution with zoom: higher zoom = sharper detail, lower zoom = faster render
        let size = z >= 14 ? 128 : z >= 11 ? 96 : 64
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let cell = CGFloat(size)  // fill whole tile per cell (1px each)
            for row in 0..<size {
                for col in 0..<size {
                    // row 0 = top of tile = maxLat (tiles go N→S)
                    let lat = maxLat - Double(row) / Double(size) * (maxLat - minLat)
                    let lon = minLon + Double(col) / Double(size) * (maxLon - minLon)
                    let v = crimeValue(lat: lat, lon: lon)
                    let (r, g, b) = crimeRGB(v)
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

    // MARK: - Web Mercator tile → lat/lon

    static func tileBounds(z: Int, x: Int, y: Int)
        -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        let n = pow(2.0, Double(z))
        let lonMin = Double(x)     / n * 360.0 - 180.0
        let lonMax = Double(x + 1) / n * 360.0 - 180.0
        // Mercator: y=0 is northernmost tile
        let latMaxRad = atan(sinh(.pi * (1.0 - 2.0 * Double(y)     / n)))
        let latMinRad = atan(sinh(.pi * (1.0 - 2.0 * Double(y + 1) / n)))
        return (latMinRad * 180 / .pi, latMaxRad * 180 / .pi, lonMin, lonMax)
    }

    // MARK: - Crime model (identical to CrimeHeatmapView)

    static func crimeValue(lat: Double, lon: Double) -> Double {
        let hotspots: [(Double, Double, Double, Double)] = [
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
        let safeZones: [(Double, Double, Double, Double)] = [
            (37.322, -122.040, 0.50, 4.0), (37.265, -122.030, 0.55, 3.5),
            (37.440, -122.165, 0.60, 4.5), (37.378, -122.100, 0.55, 3.5),
            (37.863, -122.248, 0.55, 2.5), (37.882, -122.165, 0.60, 4.0),
            (37.822, -121.978, 0.58, 4.0), (37.662, -121.878, 0.58, 3.5),
            (37.895, -122.512, 0.60, 5.0), (37.568, -122.320, 0.45, 4.0),
            (37.928, -122.108, 0.48, 4.0),
        ]
        let mpLat = 69.0, mpLon = 53.0
        var v = 0.15
        for h in hotspots {
            let d2 = pow((lat - h.0) * mpLat, 2) + pow((lon - h.1) * mpLon, 2)
            v += h.2 * exp(-d2 / (h.3 * h.3))
        }
        for s in safeZones {
            let d2 = pow((lat - s.0) * mpLat, 2) + pow((lon - s.1) * mpLon, 2)
            v -= s.2 * exp(-d2 / (s.3 * s.3))
        }
        return max(0.10, min(1.0, v))
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
