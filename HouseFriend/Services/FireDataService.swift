import Foundation
import MapKit

struct FireHazardZone: Identifiable {
    let id = UUID()
    let name: String
    let coordinates: [CLLocationCoordinate2D]
    let severity: String  // "High", "Very High", "Extreme"
}

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
        hazardZones = Self.allBayAreaFireZones()
        isLoading = false
    }

    static func allBayAreaFireZones() -> [FireHazardZone] {
        return [

            // ═══ SANTA CLARA COUNTY ═══════════════════════════════════════════

            FireHazardZone(name: "Sierra Azul (Extreme)", coordinates: [
                .init(latitude: 37.310, longitude: -122.030),
                .init(latitude: 37.295, longitude: -122.010),
                .init(latitude: 37.270, longitude: -122.000),
                .init(latitude: 37.255, longitude: -122.020),
                .init(latitude: 37.265, longitude: -122.055),
                .init(latitude: 37.285, longitude: -122.070),
                .init(latitude: 37.310, longitude: -122.060),
            ], severity: "Extreme"),

            FireHazardZone(name: "Cupertino Hills (Very High)", coordinates: [
                .init(latitude: 37.340, longitude: -122.100),
                .init(latitude: 37.325, longitude: -122.082),
                .init(latitude: 37.308, longitude: -122.068),
                .init(latitude: 37.295, longitude: -122.080),
                .init(latitude: 37.305, longitude: -122.108),
                .init(latitude: 37.325, longitude: -122.115),
            ], severity: "Very High"),

            FireHazardZone(name: "Almaden Hills (Very High)", coordinates: [
                .init(latitude: 37.265, longitude: -121.900),
                .init(latitude: 37.248, longitude: -121.878),
                .init(latitude: 37.238, longitude: -121.855),
                .init(latitude: 37.248, longitude: -121.835),
                .init(latitude: 37.270, longitude: -121.850),
                .init(latitude: 37.282, longitude: -121.875),
                .init(latitude: 37.275, longitude: -121.900),
            ], severity: "Very High"),

            FireHazardZone(name: "Alum Rock Foothills (High)", coordinates: [
                .init(latitude: 37.395, longitude: -121.840),
                .init(latitude: 37.380, longitude: -121.818),
                .init(latitude: 37.360, longitude: -121.808),
                .init(latitude: 37.352, longitude: -121.828),
                .init(latitude: 37.368, longitude: -121.848),
                .init(latitude: 37.385, longitude: -121.855),
            ], severity: "High"),

            FireHazardZone(name: "Monte Bello Ridge (High)", coordinates: [
                .init(latitude: 37.335, longitude: -122.145),
                .init(latitude: 37.318, longitude: -122.128),
                .init(latitude: 37.300, longitude: -122.120),
                .init(latitude: 37.292, longitude: -122.140),
                .init(latitude: 37.308, longitude: -122.162),
                .init(latitude: 37.330, longitude: -122.162),
            ], severity: "High"),

            // ═══ EAST BAY — ALAMEDA / CONTRA COSTA ═══════════════════════════

            // 1991 Oakland-Berkeley Tunnel Fire — historically most destructive CA urban fire
            FireHazardZone(name: "Oakland-Berkeley Hills (Extreme)", coordinates: [
                .init(latitude: 37.882, longitude: -122.212),
                .init(latitude: 37.870, longitude: -122.205),
                .init(latitude: 37.855, longitude: -122.208),
                .init(latitude: 37.848, longitude: -122.218),
                .init(latitude: 37.840, longitude: -122.225),
                .init(latitude: 37.835, longitude: -122.238),
                .init(latitude: 37.848, longitude: -122.248),
                .init(latitude: 37.862, longitude: -122.248),
                .init(latitude: 37.875, longitude: -122.238),
                .init(latitude: 37.882, longitude: -122.225),
            ], severity: "Extreme"),

            FireHazardZone(name: "Claremont Hills / Rockridge (Very High)", coordinates: [
                .init(latitude: 37.858, longitude: -122.230),
                .init(latitude: 37.845, longitude: -122.218),
                .init(latitude: 37.832, longitude: -122.225),
                .init(latitude: 37.828, longitude: -122.242),
                .init(latitude: 37.838, longitude: -122.255),
                .init(latitude: 37.852, longitude: -122.252),
            ], severity: "Very High"),

            FireHazardZone(name: "Montclair / Piedmont Hills (Very High)", coordinates: [
                .init(latitude: 37.828, longitude: -122.208),
                .init(latitude: 37.815, longitude: -122.198),
                .init(latitude: 37.805, longitude: -122.205),
                .init(latitude: 37.808, longitude: -122.225),
                .init(latitude: 37.820, longitude: -122.232),
                .init(latitude: 37.830, longitude: -122.222),
            ], severity: "Very High"),

            FireHazardZone(name: "Tilden Park / Wildcat Hills (Very High)", coordinates: [
                .init(latitude: 37.895, longitude: -122.242),
                .init(latitude: 37.882, longitude: -122.230),
                .init(latitude: 37.870, longitude: -122.238),
                .init(latitude: 37.872, longitude: -122.258),
                .init(latitude: 37.885, longitude: -122.265),
                .init(latitude: 37.898, longitude: -122.258),
            ], severity: "Very High"),

            FireHazardZone(name: "Orinda / Moraga Hills (Very High)", coordinates: [
                .init(latitude: 37.888, longitude: -122.192),
                .init(latitude: 37.870, longitude: -122.178),
                .init(latitude: 37.852, longitude: -122.168),
                .init(latitude: 37.840, longitude: -122.178),
                .init(latitude: 37.845, longitude: -122.202),
                .init(latitude: 37.862, longitude: -122.210),
                .init(latitude: 37.880, longitude: -122.205),
            ], severity: "Very High"),

            FireHazardZone(name: "Lafayette / Walnut Creek Hills (High)", coordinates: [
                .init(latitude: 37.912, longitude: -122.132),
                .init(latitude: 37.898, longitude: -122.118),
                .init(latitude: 37.882, longitude: -122.110),
                .init(latitude: 37.872, longitude: -122.125),
                .init(latitude: 37.878, longitude: -122.148),
                .init(latitude: 37.895, longitude: -122.158),
                .init(latitude: 37.910, longitude: -122.148),
            ], severity: "High"),

            FireHazardZone(name: "Diablo Range / Mt Diablo (Very High)", coordinates: [
                .init(latitude: 37.882, longitude: -121.932),
                .init(latitude: 37.860, longitude: -121.908),
                .init(latitude: 37.842, longitude: -121.915),
                .init(latitude: 37.838, longitude: -121.945),
                .init(latitude: 37.852, longitude: -121.968),
                .init(latitude: 37.875, longitude: -121.968),
                .init(latitude: 37.890, longitude: -121.952),
            ], severity: "Very High"),

            FireHazardZone(name: "East Bay Hills Ridgeline (High)", coordinates: [
                .init(latitude: 37.740, longitude: -122.098),
                .init(latitude: 37.718, longitude: -122.082),
                .init(latitude: 37.700, longitude: -122.075),
                .init(latitude: 37.692, longitude: -122.092),
                .init(latitude: 37.705, longitude: -122.112),
                .init(latitude: 37.722, longitude: -122.118),
                .init(latitude: 37.738, longitude: -122.112),
            ], severity: "High"),

            // ═══ MARIN COUNTY ════════════════════════════════════════════════

            FireHazardZone(name: "Mount Tamalpais (Extreme)", coordinates: [
                .init(latitude: 37.928, longitude: -122.595),
                .init(latitude: 37.912, longitude: -122.578),
                .init(latitude: 37.898, longitude: -122.565),
                .init(latitude: 37.888, longitude: -122.578),
                .init(latitude: 37.892, longitude: -122.605),
                .init(latitude: 37.908, longitude: -122.618),
                .init(latitude: 37.922, longitude: -122.612),
            ], severity: "Extreme"),

            FireHazardZone(name: "Marin Headlands (Very High)", coordinates: [
                .init(latitude: 37.838, longitude: -122.512),
                .init(latitude: 37.825, longitude: -122.498),
                .init(latitude: 37.818, longitude: -122.508),
                .init(latitude: 37.822, longitude: -122.528),
                .init(latitude: 37.835, longitude: -122.532),
            ], severity: "Very High"),

            FireHazardZone(name: "Bolinas Ridge / Point Reyes (Very High)", coordinates: [
                .init(latitude: 37.998, longitude: -122.728),
                .init(latitude: 37.975, longitude: -122.698),
                .init(latitude: 37.958, longitude: -122.682),
                .init(latitude: 37.948, longitude: -122.702),
                .init(latitude: 37.958, longitude: -122.735),
                .init(latitude: 37.978, longitude: -122.752),
                .init(latitude: 37.995, longitude: -122.748),
            ], severity: "Very High"),

            FireHazardZone(name: "Ross Valley / Fairfax Hills (High)", coordinates: [
                .init(latitude: 37.972, longitude: -122.608),
                .init(latitude: 37.958, longitude: -122.592),
                .init(latitude: 37.945, longitude: -122.598),
                .init(latitude: 37.948, longitude: -122.622),
                .init(latitude: 37.962, longitude: -122.632),
                .init(latitude: 37.975, longitude: -122.622),
            ], severity: "High"),

            // ═══ SAN MATEO COUNTY ════════════════════════════════════════════

            FireHazardZone(name: "Portola Valley / Woodside Hills (Very High)", coordinates: [
                .init(latitude: 37.388, longitude: -122.232),
                .init(latitude: 37.368, longitude: -122.212),
                .init(latitude: 37.350, longitude: -122.205),
                .init(latitude: 37.340, longitude: -122.222),
                .init(latitude: 37.348, longitude: -122.252),
                .init(latitude: 37.368, longitude: -122.265),
                .init(latitude: 37.385, longitude: -122.252),
            ], severity: "Very High"),

            FireHazardZone(name: "Crystal Springs / Purisima (High)", coordinates: [
                .init(latitude: 37.502, longitude: -122.358),
                .init(latitude: 37.482, longitude: -122.335),
                .init(latitude: 37.462, longitude: -122.325),
                .init(latitude: 37.455, longitude: -122.342),
                .init(latitude: 37.468, longitude: -122.368),
                .init(latitude: 37.488, longitude: -122.375),
                .init(latitude: 37.502, longitude: -122.368),
            ], severity: "High"),

            FireHazardZone(name: "Santa Cruz Mountains (Very High)", coordinates: [
                .init(latitude: 37.208, longitude: -122.108),
                .init(latitude: 37.185, longitude: -122.082),
                .init(latitude: 37.165, longitude: -122.065),
                .init(latitude: 37.152, longitude: -122.085),
                .init(latitude: 37.162, longitude: -122.118),
                .init(latitude: 37.182, longitude: -122.135),
                .init(latitude: 37.202, longitude: -122.125),
            ], severity: "Very High"),

            // ═══ SONOMA / NAPA (NORTH BAY) ════════════════════════════════════

            FireHazardZone(name: "Sonoma Mountain (Very High)", coordinates: [
                .init(latitude: 38.302, longitude: -122.562),
                .init(latitude: 38.282, longitude: -122.538),
                .init(latitude: 38.265, longitude: -122.532),
                .init(latitude: 38.258, longitude: -122.555),
                .init(latitude: 38.268, longitude: -122.578),
                .init(latitude: 38.285, longitude: -122.585),
                .init(latitude: 38.302, longitude: -122.572),
            ], severity: "Very High"),

            FireHazardZone(name: "Napa Hills / Vaca Mountains (High)", coordinates: [
                .init(latitude: 38.322, longitude: -122.228),
                .init(latitude: 38.302, longitude: -122.208),
                .init(latitude: 38.282, longitude: -122.202),
                .init(latitude: 38.272, longitude: -122.222),
                .init(latitude: 38.282, longitude: -122.252),
                .init(latitude: 38.305, longitude: -122.262),
                .init(latitude: 38.322, longitude: -122.248),
            ], severity: "High"),

            // ═══ TRI-VALLEY / LIVERMORE ══════════════════════════════════════

            FireHazardZone(name: "Livermore Hills / Del Valle (High)", coordinates: [
                .init(latitude: 37.668, longitude: -121.808),
                .init(latitude: 37.648, longitude: -121.785),
                .init(latitude: 37.628, longitude: -121.778),
                .init(latitude: 37.620, longitude: -121.800),
                .init(latitude: 37.632, longitude: -121.828),
                .init(latitude: 37.652, longitude: -121.838),
                .init(latitude: 37.668, longitude: -121.822),
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
