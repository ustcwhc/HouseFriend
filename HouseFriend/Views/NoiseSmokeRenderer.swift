import MapKit
import UIKit

/// Custom polyline renderer that draws a dark smoke/haze effect along noisy roads.
/// Multiple semi-transparent layers at increasing widths create a diffuse cloud look.
final class NoiseSmokeRenderer: MKOverlayRenderer {

    let polyline: MKPolyline
    let dbLevel: Int
    let baseLineWidth: CGFloat
    let isRailway: Bool

    init(polyline: MKPolyline, dbLevel: Int, lineWidth: CGFloat, isRailway: Bool) {
        self.polyline = polyline
        self.dbLevel = dbLevel
        self.baseLineWidth = lineWidth
        self.isRailway = isRailway
        super.init(overlay: polyline)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in ctx: CGContext) {
        let count = polyline.pointCount
        guard count >= 2 else { return }

        // Build path in renderer coordinates
        let pts = polyline.points()
        let path = CGMutablePath()
        path.move(to: point(for: pts[0]))
        for i in 1..<count {
            path.addLine(to: point(for: pts[i]))
        }

        // Scale line width by zoom (MKOverlayRenderer coordinate space)
        let road = baseLineWidth / zoomScale

        // Noise intensity: 0.0 (quiet, ≤40 dB) → 1.0 (loud, ≥78 dB)
        let intensity = CGFloat(min(max(Double(dbLevel) - 40.0, 0), 38.0) / 38.0)

        // --- Layer 1: Wide outer haze ---
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setLineWidth(road * 12)
        ctx.setStrokeColor(UIColor(white: 0.08, alpha: 0.025 * intensity).cgColor)
        ctx.strokePath()
        ctx.restoreGState()

        // --- Layer 2: Mid haze ---
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setLineWidth(road * 6)
        ctx.setStrokeColor(UIColor(white: 0.10, alpha: 0.06 * intensity).cgColor)
        ctx.strokePath()
        ctx.restoreGState()

        // --- Layer 3: Inner smoke ---
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setLineWidth(road * 3)
        ctx.setStrokeColor(UIColor(white: 0.12, alpha: 0.12 * intensity).cgColor)
        ctx.strokePath()
        ctx.restoreGState()

        // --- Layer 4: Core colored line ---
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setLineWidth(road)
        let color = UIColor(NoiseService.color(for: dbLevel))
        ctx.setStrokeColor(color.withAlphaComponent(0.75).cgColor)
        if isRailway {
            ctx.setLineDash(phase: 0, lengths: [road * 3, road * 2])
        }
        ctx.strokePath()
        ctx.restoreGState()
    }
}
