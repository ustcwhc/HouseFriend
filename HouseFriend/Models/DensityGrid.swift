import Foundation
import MapKit

// MARK: - DensityGrid

/// Spatial density grid for heatmap rendering and cluster markers.
/// Divides a geographic region into cells and counts incidents per cell.
struct DensityGrid {
    let origin: CLLocationCoordinate2D  // SW corner
    let cellSize: Double = 0.005        // degrees per cell
    let rows: Int                       // latitude divisions
    let cols: Int                       // longitude divisions
    let counts: [[Int]]                 // [row][col] incident counts
    let maxCount: Int                   // maximum count in any cell, for normalization

    // MARK: - Intensity lookup

    /// Returns normalized 0.0-1.0 intensity for a coordinate.
    /// Applies smooth edge falloff to avoid hard rectangular cutoff.
    /// Returns 0.0 for coordinates well outside the grid.
    func intensity(lat: Double, lon: Double) -> Double {
        guard lat.isFinite, lon.isFinite else { return 0.0 }
        guard maxCount > 0 else { return 0.0 }

        let rowF = (lat - origin.latitude) / cellSize
        let colF = (lon - origin.longitude) / cellSize

        // Hard reject if far outside grid
        guard rowF > -2, rowF < Double(rows + 2), colF > -2, colF < Double(cols + 2) else { return 0.0 }

        let row = Int(rowF)
        let col = Int(colF)

        // Get raw value (0 if outside grid bounds)
        let rawCount: Int
        if row >= 0, row < rows, col >= 0, col < cols {
            rawCount = counts[row][col]
        } else {
            rawCount = 0
        }

        let rawIntensity = Double(rawCount) / Double(maxCount)

        // Smooth edge falloff — fade to 0 within 15% of grid edges
        let fadeMargin = 0.15
        let rowNorm = rowF / Double(rows)  // 0.0 at bottom, 1.0 at top
        let colNorm = colF / Double(cols)  // 0.0 at left, 1.0 at right

        let fadeBottom = min(1.0, rowNorm / fadeMargin)
        let fadeTop    = min(1.0, (1.0 - rowNorm) / fadeMargin)
        let fadeLeft   = min(1.0, colNorm / fadeMargin)
        let fadeRight  = min(1.0, (1.0 - colNorm) / fadeMargin)

        let edgeFade = max(0.0, min(fadeBottom, fadeTop, fadeLeft, fadeRight))
        return rawIntensity * edgeFade
    }

    // MARK: - Factory

    /// Builds a density grid from incidents within a map region.
    static func build(from incidents: [CrimeIncident], region: MKCoordinateRegion) -> DensityGrid {
        let cellSize = 0.005

        // Compute origin as SW corner
        let originLat = region.center.latitude - region.span.latitudeDelta / 2
        let originLon = region.center.longitude - region.span.longitudeDelta / 2

        // Compute grid dimensions
        let rows = max(1, Int(region.span.latitudeDelta / cellSize))
        let cols = max(1, Int(region.span.longitudeDelta / cellSize))

        // Build counts grid
        var counts = Array(repeating: Array(repeating: 0, count: cols), count: rows)
        var maxCount = 0

        for incident in incidents {
            let lat = incident.coordinate.latitude
            let lon = incident.coordinate.longitude
            guard lat.isFinite, lon.isFinite else { continue }

            let row = Int((lat - originLat) / cellSize)
            let col = Int((lon - originLon) / cellSize)
            guard row >= 0, row < rows, col >= 0, col < cols else { continue }

            counts[row][col] += 1
            if counts[row][col] > maxCount {
                maxCount = counts[row][col]
            }
        }

        return DensityGrid(
            origin: CLLocationCoordinate2D(latitude: originLat, longitude: originLon),
            rows: rows,
            cols: cols,
            counts: counts,
            maxCount: maxCount
        )
    }
}
