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
    /// Returns 0.0 for out-of-bounds coordinates.
    func intensity(lat: Double, lon: Double) -> Double {
        guard lat.isFinite, lon.isFinite else { return 0.0 }
        let row = Int((lat - origin.latitude) / cellSize)
        let col = Int((lon - origin.longitude) / cellSize)
        guard row >= 0, row < rows, col >= 0, col < cols else { return 0.0 }
        guard maxCount > 0 else { return 0.0 }
        return Double(counts[row][col]) / Double(maxCount)
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
