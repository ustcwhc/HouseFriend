import Foundation
import MapKit

enum GeoJSONError: Error {
    case invalidFormat
    case missingGeometry
}

struct GeoJSONParser {
    static func parsePolygon(from coordinates: [[[Double]]]) -> MKPolygon? {
        guard !coordinates.isEmpty else { return nil }
        let exteriorRing = coordinates[0]
        let points = exteriorRing.map { coord -> CLLocationCoordinate2D in
            CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
        }
        return MKPolygon(coordinates: points, count: points.count)
    }
}
