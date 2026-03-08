import Foundation
import MapKit

enum GeoJSONError: Error {
    case invalidFormat
    case missingGeometry
}

struct GeoJSONParser {
    static func parsePolygon(from coordinates: [[[Double]]]) -> MKPolygon? {
        guard !coordinates.isEmpty else { return nil }
        
        // 我们取第一个环（外环）
        let exteriorRing = coordinates[0]
        let points = exteriorRing.map { coord -> CLLocationCoordinate2D in
            // GeoJSON 是 [longitude, latitude]
            return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
        }
        
        return MKPolygon(coordinates: points, count: points.count)
    }
    
    // 专门解析 SFUSD 的 JSON 格式 (DataSF API 返回的通常是这种结构)
    static func parseSFUSD(data: Data) -> [SchoolBoundary] {
        var results: [SchoolBoundary] = []
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                for item in json {
                    guard let name = item["school_name"] as? String,
                          let level = item["school_level"] as? String,
                          let geometry = item["the_geom"] as? [String: Any],
                          let type = geometry["type"] as? String,
                          let coords = geometry["coordinates"] as? [[[Double]]],
                          type == "MultiPolygon" || type == "Polygon" else { continue }
                    
                    // 简化处理：如果是 MultiPolygon，我们也只取第一个 Polygon 的第一个环
                    // 实际开发中可以循环解析所有 Polygon
                    if let polygon = parsePolygon(from: coords) {
                        results.append(SchoolBoundary(name: name, schoolLevel: level, polygon: polygon))
                    }
                }
            }
        } catch {
            print("JSON Parsing error: \(error)")
        }
        
        return results
    }
}
