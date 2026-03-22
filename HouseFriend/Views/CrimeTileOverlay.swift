import MapKit
import UIKit

/// MKTileOverlay that renders crime heatmap tiles from a DensityGrid.
/// Tiles are generated on a background thread and cached by MapKit automatically.
/// Because tiles live in MapKit's coordinate space, the overlay follows
/// map panning/zooming perfectly with zero lag.
class CrimeTileOverlay: MKTileOverlay {

    // MARK: - Thread-safe density grid property

    private let gridLock = NSLock()
    private var _densityGrid: DensityGrid?
    var densityGrid: DensityGrid? {
        get { gridLock.lock(); defer { gridLock.unlock() }; return _densityGrid }
        set { gridLock.lock(); defer { gridLock.unlock() }; _densityGrid = newValue }
    }

    override init(urlTemplate: String? = nil) {
        super.init(urlTemplate: nil)
        self.tileSize = CGSize(width: 256, height: 256)
        self.minimumZ = 7
        self.maximumZ = 17
        self.canReplaceMapContent = false   // keep base map visible underneath
    }

    override func loadTile(at path: MKTileOverlayPath,
                           result: @escaping (Data?, Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { result(nil, nil); return }
            let data = self.renderTile(z: path.z, x: path.x, y: path.y)
            result(data, nil)
        }
    }

    // MARK: - Tile generation

    func renderTile(z: Int, x: Int, y: Int) -> Data? {
        let (minLat, maxLat, minLon, maxLon) = Self.tileBounds(z: z, x: x, y: y)

        // Skip tiles clearly outside Bay Area
        guard maxLat > 36.8 && minLat < 38.9 &&
              maxLon > -123.5 && minLon < -121.0 else { return nil }

        // Scale resolution with zoom: higher zoom = sharper detail, lower zoom = faster render
        let size = z >= 14 ? 128 : z >= 11 ? 96 : 64
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            for row in 0..<size {
                for col in 0..<size {
                    // row 0 = top of tile = maxLat (tiles go N->S)
                    let lat = maxLat - Double(row) / Double(size) * (maxLat - minLat)
                    let lon = minLon + Double(col) / Double(size) * (maxLon - minLon)
                    let v = crimeValue(lat: lat, lon: lon)
                    guard v > 0.0 else { continue }  // Skip transparent pixels
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
        // Mercator: y=0 is northernmost tile
        let latMaxRad = atan(sinh(.pi * (1.0 - 2.0 * Double(y)     / n)))
        let latMinRad = atan(sinh(.pi * (1.0 - 2.0 * Double(y + 1) / n)))
        return (latMinRad * 180 / .pi, latMaxRad * 180 / .pi, lonMin, lonMax)
    }

    // MARK: - Crime value from density grid

    /// Returns crime intensity for a coordinate using the density grid.
    /// Returns 0.0 when no density grid is available (no fake heatmap).
    func crimeValue(lat: Double, lon: Double) -> Double {
        guard let grid = densityGrid else { return 0.0 }
        let raw = grid.intensity(lat: lat, lon: lon)
        guard raw.isFinite else { return 0.0 }
        guard raw > 0.0 else { return 0.0 }
        return max(0.10, min(1.0, 0.10 + raw * 0.90))
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
