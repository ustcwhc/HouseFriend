import SwiftUI
import MapKit
import UIKit

// MARK: - UIViewRepresentable wrapper
struct CrimeHeatmapOverlay: UIViewRepresentable {
    let region: MKCoordinateRegion

    func makeUIView(context: Context) -> CrimeHeatmapView {
        let v = CrimeHeatmapView()
        v.backgroundColor = .clear
        v.isOpaque = false
        return v
    }

    func updateUIView(_ uiView: CrimeHeatmapView, context: Context) {
        uiView.region = region
        uiView.setNeedsDisplay()
    }
}

// MARK: - Core Graphics raster renderer
class CrimeHeatmapView: UIView {
    var region: MKCoordinateRegion = MKCoordinateRegion()

    // 90×90 sample grid — bilinear interpolated to full resolution by CoreGraphics
    private let G = 90

    override func draw(_ rect: CGRect) {
        let minLat = region.center.latitude  - region.span.latitudeDelta  / 2
        let maxLat = region.center.latitude  + region.span.latitudeDelta  / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2
        guard maxLat > minLat, maxLon > minLon else { return }
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Draw colored cells directly via CGContext — avoids premultiplied alpha bugs
        let cellW = rect.width  / CGFloat(G)
        let cellH = rect.height / CGFloat(G)

        for row in 0..<G {
            for col in 0..<G {
                let lat = maxLat - Double(row) / Double(G) * (maxLat - minLat)
                let lon = minLon  + Double(col) / Double(G) * (maxLon - minLon)
                let v   = Self.crimeValue(lat: lat, lon: lon)
                let (r, g, b) = Self.crimeRGB(v)
                let alpha = min(0.72, max(0.38, v * 0.82))
                ctx.setFillColor(red:   CGFloat(r)/255,
                                 green: CGFloat(g)/255,
                                 blue:  CGFloat(b)/255,
                                 alpha: CGFloat(alpha))
                ctx.fill(CGRect(x: CGFloat(col)*cellW, y: CGFloat(row)*cellH,
                                width: cellW+0.5, height: cellH+0.5))
            }
        }
    }

    // MARK: - Crime value at coordinate (same hotspot model as ContentView)
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
            let d2 = pow((lat-h.0)*mpLat,2) + pow((lon-h.1)*mpLon,2)
            v += h.2 * exp(-d2/(h.3*h.3))
        }
        for s in safeZones {
            let d2 = pow((lat-s.0)*mpLat,2) + pow((lon-s.1)*mpLon,2)
            v -= s.2 * exp(-d2/(s.3*s.3))
        }
        return max(0.10, min(1.0, v))
    }

    static func crimeRGB(_ v: Double) -> (UInt8, UInt8, UInt8) {
        // Deep red → orange-red → orange → amber → light amber
        if v >= 0.72 { return (191,  13,  13) }
        if v >= 0.55 { return (235,  64,  20) }
        if v >= 0.40 { return (250, 133,  38) }
        if v >= 0.28 { return (254, 184,  89) }
        if v >= 0.18 { return (255, 219, 153) }
        return               (255, 238, 200)
    }
}
