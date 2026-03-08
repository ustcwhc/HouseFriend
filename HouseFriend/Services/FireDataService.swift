import Foundation
import MapKit

struct FireHazardZone: Identifiable {
    let id = UUID()
    let name: String
    let coordinates: [CLLocationCoordinate2D]
    let severity: String  // "High", "Very High", "Extreme"
}

// Legacy type kept for compatibility
struct FireHazardArea: Identifiable {
    let id = UUID()
    let name: String
    let coordinates: [CLLocationCoordinate2D]
    let severity: String
}

class FireDataService: ObservableObject {
    @Published var hazardZones: [FireHazardZone] = []
    @Published var isLoading = false

    func fetchFireData() {
        isLoading = true
        hazardZones = Self.calFireSRAZones()
        isLoading = false
    }

    /// CAL FIRE State Responsibility Area (SRA) Fire Hazard Severity Zones
    /// Approximate boundaries for Santa Clara County based on published data
    static func calFireSRAZones() -> [FireHazardZone] {
        return [
            // EXTREME — Los Gatos hills / Sierra Azul
            FireHazardZone(name: "Sierra Azul (Extreme)", coordinates: [
                CLLocationCoordinate2D(latitude: 37.310, longitude: -122.030),
                CLLocationCoordinate2D(latitude: 37.295, longitude: -122.010),
                CLLocationCoordinate2D(latitude: 37.270, longitude: -122.000),
                CLLocationCoordinate2D(latitude: 37.255, longitude: -122.020),
                CLLocationCoordinate2D(latitude: 37.265, longitude: -122.055),
                CLLocationCoordinate2D(latitude: 37.285, longitude: -122.070),
                CLLocationCoordinate2D(latitude: 37.310, longitude: -122.060),
            ], severity: "Extreme"),

            // VERY HIGH — Cupertino hills / Fremont Older preserve
            FireHazardZone(name: "Cupertino Hills (Very High)", coordinates: [
                CLLocationCoordinate2D(latitude: 37.340, longitude: -122.100),
                CLLocationCoordinate2D(latitude: 37.325, longitude: -122.082),
                CLLocationCoordinate2D(latitude: 37.308, longitude: -122.068),
                CLLocationCoordinate2D(latitude: 37.295, longitude: -122.080),
                CLLocationCoordinate2D(latitude: 37.305, longitude: -122.108),
                CLLocationCoordinate2D(latitude: 37.325, longitude: -122.115),
            ], severity: "Very High"),

            // VERY HIGH — Almaden hills / Calero reservoir
            FireHazardZone(name: "Almaden Hills (Very High)", coordinates: [
                CLLocationCoordinate2D(latitude: 37.265, longitude: -121.900),
                CLLocationCoordinate2D(latitude: 37.248, longitude: -121.878),
                CLLocationCoordinate2D(latitude: 37.238, longitude: -121.855),
                CLLocationCoordinate2D(latitude: 37.248, longitude: -121.835),
                CLLocationCoordinate2D(latitude: 37.270, longitude: -121.850),
                CLLocationCoordinate2D(latitude: 37.282, longitude: -121.875),
                CLLocationCoordinate2D(latitude: 37.275, longitude: -121.900),
            ], severity: "Very High"),

            // HIGH — Eastern foothills north of Alum Rock
            FireHazardZone(name: "Alum Rock Foothills (High)", coordinates: [
                CLLocationCoordinate2D(latitude: 37.395, longitude: -121.840),
                CLLocationCoordinate2D(latitude: 37.380, longitude: -121.818),
                CLLocationCoordinate2D(latitude: 37.360, longitude: -121.808),
                CLLocationCoordinate2D(latitude: 37.352, longitude: -121.828),
                CLLocationCoordinate2D(latitude: 37.368, longitude: -121.848),
                CLLocationCoordinate2D(latitude: 37.385, longitude: -121.855),
            ], severity: "High"),

            // HIGH — Monte Bello ridge / Black Mountain
            FireHazardZone(name: "Monte Bello (High)", coordinates: [
                CLLocationCoordinate2D(latitude: 37.335, longitude: -122.145),
                CLLocationCoordinate2D(latitude: 37.318, longitude: -122.128),
                CLLocationCoordinate2D(latitude: 37.300, longitude: -122.120),
                CLLocationCoordinate2D(latitude: 37.292, longitude: -122.140),
                CLLocationCoordinate2D(latitude: 37.308, longitude: -122.162),
                CLLocationCoordinate2D(latitude: 37.330, longitude: -122.162),
            ], severity: "High"),
        ]
    }

    static func colorForSeverity(_ severity: String) -> (r: Double, g: Double, b: Double, opacity: Double) {
        switch severity {
        case "Extreme":   return (0.85, 0.0,  0.0,  0.50)
        case "Very High": return (0.95, 0.35, 0.0,  0.42)
        case "High":      return (1.0,  0.65, 0.0,  0.35)
        default:          return (1.0,  0.85, 0.0,  0.28)
        }
    }
}
