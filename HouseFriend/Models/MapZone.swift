import Foundation
import MapKit

struct MapZone: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let value: Double  // generic value (intensity 0-1, or odor level 1-3, etc.)
}
