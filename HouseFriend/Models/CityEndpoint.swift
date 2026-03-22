import Foundation
import MapKit

// MARK: - Field mapping

/// Per-city field name mapping for Socrata SODA API responses.
struct FieldMapping {
    let geoColumn: String
    let category: String
    let datetime: String
    let description: String
    /// Fields actually present in the JSON response (may differ from geoColumn used in $where)
    let parseFields: [String]

    /// All fields required for successful parsing — uses parseFields, not geoColumn,
    /// because some APIs (SF) expose lat/lon as separate columns even though the
    /// $where filter uses the geo column name.
    var requiredFields: [String] {
        parseFields + [category, datetime]
    }
}

// MARK: - CityEndpoint

/// Registry entry for a city's crime data SODA API endpoint.
struct CityEndpoint {
    let name: String
    let baseURL: String
    let boundingBox: (swLat: Double, swLon: Double, neLat: Double, neLon: Double)
    let fieldMapping: FieldMapping

    // MARK: - Static registry

    static let endpoints: [CityEndpoint] = [
        CityEndpoint(
            name: "San Francisco",
            baseURL: "https://data.sfgov.org/resource/wg3w-h783.json",
            boundingBox: (swLat: 37.708, swLon: -122.515, neLat: 37.812, neLon: -122.357),
            fieldMapping: FieldMapping(
                geoColumn: "point",
                category: "incident_category",
                datetime: "incident_datetime",
                description: "incident_description",
                parseFields: ["latitude", "longitude", "incident_category", "incident_datetime"]
            )
        ),
        CityEndpoint(
            name: "Oakland",
            baseURL: "https://data.oaklandca.gov/resource/ym6k-rx7a.json",
            boundingBox: (swLat: 37.733, swLon: -122.335, neLat: 37.885, neLon: -122.115),
            fieldMapping: FieldMapping(
                geoColumn: "location_1",
                category: "crimetype",
                datetime: "datetime",
                description: "description",
                parseFields: ["location_1", "crimetype", "datetime"]
            )
        )
    ]

    // MARK: - Region matching

    /// Returns endpoints whose bounding box overlaps a circle of radius `span` degrees around the coordinate.
    static func endpointsForRegion(lat: Double, lon: Double, span: Double) -> [CityEndpoint] {
        endpoints.filter { endpoint in
            let bb = endpoint.boundingBox
            // Check if the circle around (lat, lon) overlaps the bounding box
            let latOverlap = (lat - span) <= bb.neLat && (lat + span) >= bb.swLat
            let lonOverlap = (lon - span) <= bb.neLon && (lon + span) >= bb.swLon
            return latOverlap && lonOverlap
        }
    }

    /// Checks if a coordinate falls within the bounding box (with 0.01-degree padding for edge cases).
    func contains(lat: Double, lon: Double) -> Bool {
        let padding = 0.01
        return lat >= (boundingBox.swLat - padding) &&
               lat <= (boundingBox.neLat + padding) &&
               lon >= (boundingBox.swLon - padding) &&
               lon <= (boundingBox.neLon + padding)
    }
}
