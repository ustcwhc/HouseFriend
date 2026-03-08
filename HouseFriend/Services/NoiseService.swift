import Foundation
import MapKit

struct NoiseZone: Identifiable {
    let id = UUID()
    let polygon: [CLLocationCoordinate2D]
    let dbLevel: Int   // e.g. 75 means 70-80 dB range
}

class NoiseService: ObservableObject {
    @Published var zones: [NoiseZone] = []

    func fetch() {
        // Noise zones based on DOT/FAA highway noise model for Bay Area
        // Highway corridors: 101, 280, 85, 237 -- generate approximate buffered polygons
        zones = Self.mockZones()
    }

    // dB -> SwiftUI color
    static func color(for db: Int) -> (r: Double, g: Double, b: Double) {
        switch db {
        case ..<50:  return (1.0, 1.0, 0.4)  // light yellow
        case 50..<55: return (1.0, 0.9, 0.1) // yellow
        case 55..<60: return (1.0, 0.7, 0.0) // amber
        case 60..<65: return (1.0, 0.45, 0.0) // orange
        case 65..<70: return (0.9, 0.1, 0.3) // red-orange
        case 70..<80: return (0.6, 0.0, 0.7) // purple
        default:     return (0.3, 0.0, 0.5)  // dark purple (>80)
        }
    }

    static func mockZones() -> [NoiseZone] {
        var result: [NoiseZone] = []

        // Hwy 101 corridor (very high noise >70dB near road, decreasing outward)
        // San Jose / Santa Clara stretch
        let hwy101 = [
            CLLocationCoordinate2D(latitude: 37.415, longitude: -121.940),
            CLLocationCoordinate2D(latitude: 37.380, longitude: -121.900),
            CLLocationCoordinate2D(latitude: 37.350, longitude: -121.870),
            CLLocationCoordinate2D(latitude: 37.320, longitude: -121.850),
            CLLocationCoordinate2D(latitude: 37.320, longitude: -121.820),
            CLLocationCoordinate2D(latitude: 37.350, longitude: -121.840),
            CLLocationCoordinate2D(latitude: 37.380, longitude: -121.870),
            CLLocationCoordinate2D(latitude: 37.415, longitude: -121.910),
        ]
        result.append(NoiseZone(polygon: hwy101, dbLevel: 75))

        // Hwy 280 corridor
        let hwy280 = [
            CLLocationCoordinate2D(latitude: 37.420, longitude: -122.090),
            CLLocationCoordinate2D(latitude: 37.360, longitude: -122.020),
            CLLocationCoordinate2D(latitude: 37.310, longitude: -121.970),
            CLLocationCoordinate2D(latitude: 37.310, longitude: -121.940),
            CLLocationCoordinate2D(latitude: 37.360, longitude: -121.990),
            CLLocationCoordinate2D(latitude: 37.420, longitude: -122.060),
        ]
        result.append(NoiseZone(polygon: hwy280, dbLevel: 72))

        // Hwy 237 (Milpitas)
        let hwy237 = [
            CLLocationCoordinate2D(latitude: 37.430, longitude: -122.000),
            CLLocationCoordinate2D(latitude: 37.420, longitude: -121.960),
            CLLocationCoordinate2D(latitude: 37.415, longitude: -121.920),
            CLLocationCoordinate2D(latitude: 37.405, longitude: -121.920),
            CLLocationCoordinate2D(latitude: 37.410, longitude: -121.960),
            CLLocationCoordinate2D(latitude: 37.420, longitude: -121.995),
        ]
        result.append(NoiseZone(polygon: hwy237, dbLevel: 68))

        // General urban 55-60 dB background (Santa Clara / Sunnyvale area)
        let urban1 = [
            CLLocationCoordinate2D(latitude: 37.420, longitude: -122.060),
            CLLocationCoordinate2D(latitude: 37.380, longitude: -122.030),
            CLLocationCoordinate2D(latitude: 37.350, longitude: -122.010),
            CLLocationCoordinate2D(latitude: 37.340, longitude: -121.970),
            CLLocationCoordinate2D(latitude: 37.360, longitude: -121.950),
            CLLocationCoordinate2D(latitude: 37.400, longitude: -121.960),
            CLLocationCoordinate2D(latitude: 37.430, longitude: -122.000),
        ]
        result.append(NoiseZone(polygon: urban1, dbLevel: 57))

        // Quieter suburban 50-55 dB (Cupertino hills area)
        let quiet1 = [
            CLLocationCoordinate2D(latitude: 37.335, longitude: -122.050),
            CLLocationCoordinate2D(latitude: 37.310, longitude: -122.020),
            CLLocationCoordinate2D(latitude: 37.295, longitude: -122.010),
            CLLocationCoordinate2D(latitude: 37.290, longitude: -122.040),
            CLLocationCoordinate2D(latitude: 37.310, longitude: -122.060),
            CLLocationCoordinate2D(latitude: 37.330, longitude: -122.070),
        ]
        result.append(NoiseZone(polygon: quiet1, dbLevel: 52))

        return result
    }
}
