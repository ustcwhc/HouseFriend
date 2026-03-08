import Foundation
import MapKit

struct NoiseRing: Identifiable {
    let id = UUID()
    let center: CLLocationCoordinate2D
    let radiusMeters: Double
    let dbLevel: Int
}

struct NoiseZone: Identifiable {
    let id = UUID()
    let polygon: [CLLocationCoordinate2D]
    let dbLevel: Int
}

class NoiseService: ObservableObject {
    @Published var rings: [NoiseRing] = []
    @Published var zones: [NoiseZone] = []   // kept for legacy

    func fetch() {
        rings = Self.generateRings()
    }

    // dB -> RGBA color (matches screenshot: yellow→orange→red→purple)
    static func color(for db: Int) -> (r: Double, g: Double, b: Double) {
        switch db {
        case ..<50:    return (1.0, 1.0, 0.4)
        case 50..<55:  return (1.0, 0.92, 0.1)
        case 55..<60:  return (1.0, 0.72, 0.0)
        case 60..<65:  return (1.0, 0.45, 0.0)
        case 65..<70:  return (0.92, 0.1,  0.3)
        case 70..<80:  return (0.60, 0.0,  0.72)
        default:       return (0.28, 0.0,  0.50)   // > 80 dB
        }
    }

    /// Generate concentric noise rings along highway corridors.
    /// Each highway segment contributes ~8 rings at increasing distances,
    /// so they blend into a smooth smoke/haze gradient.
    static func generateRings() -> [NoiseRing] {
        var result: [NoiseRing] = []

        // (center point, peak dB at center)
        let sources: [(CLLocationCoordinate2D, Int)] = [
            // US-101 SJ / Santa Clara
            (CLLocationCoordinate2D(latitude: 37.415, longitude: -121.942), 78),
            (CLLocationCoordinate2D(latitude: 37.393, longitude: -121.916), 78),
            (CLLocationCoordinate2D(latitude: 37.368, longitude: -121.893), 77),
            (CLLocationCoordinate2D(latitude: 37.345, longitude: -121.873), 76),
            (CLLocationCoordinate2D(latitude: 37.322, longitude: -121.852), 75),
            // I-280
            (CLLocationCoordinate2D(latitude: 37.418, longitude: -122.088), 75),
            (CLLocationCoordinate2D(latitude: 37.390, longitude: -122.060), 75),
            (CLLocationCoordinate2D(latitude: 37.360, longitude: -122.032), 74),
            (CLLocationCoordinate2D(latitude: 37.330, longitude: -122.005), 73),
            // SR-237 (Milpitas)
            (CLLocationCoordinate2D(latitude: 37.428, longitude: -122.002), 72),
            (CLLocationCoordinate2D(latitude: 37.420, longitude: -121.965), 72),
            (CLLocationCoordinate2D(latitude: 37.415, longitude: -121.932), 71),
            // I-880
            (CLLocationCoordinate2D(latitude: 37.468, longitude: -121.928), 76),
            (CLLocationCoordinate2D(latitude: 37.445, longitude: -121.921), 76),
            (CLLocationCoordinate2D(latitude: 37.422, longitude: -121.912), 75),
            // SR-85
            (CLLocationCoordinate2D(latitude: 37.340, longitude: -122.024), 72),
            (CLLocationCoordinate2D(latitude: 37.318, longitude: -122.004), 71),
        ]

        // Ring levels: (distance in meters, dB reduction from center)
        let ringLevels: [(Double, Int)] = [
            (80,   0),   // center - darkest
            (180,  3),
            (320,  7),
            (500,  12),
            (750,  17),
            (1100, 23),
            (1600, 30),
            (2200, 38),  // outermost - nearly transparent
        ]

        for (coord, peakDb) in sources {
            for (radius, reduction) in ringLevels {
                let db = peakDb - reduction
                if db >= 45 { // skip rings below ~45 dB (essentially ambient)
                    result.append(NoiseRing(center: coord, radiusMeters: radius, dbLevel: db))
                }
            }
        }

        return result
    }
}
