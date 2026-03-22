import Foundation
import MapKit

struct ElectricLine: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let voltage: Int      // kV
    let type: String      // "AC", "DC"
}

class ElectricLinesService: ObservableObject {
    @Published var lines: [ElectricLine] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // HIFLD Electric Power Transmission Lines - Bay Area bounding box
    private let urlString = "https://services1.arcgis.com/Hp6G80Pky0om7QvQ/arcgis/rest/services/Electric_Power_Transmission_Lines/FeatureServer/0/query?where=1%3D1&geometry=%7B%22xmin%22%3A-122.6%2C%22ymin%22%3A36.8%2C%22xmax%22%3A-121.2%2C%22ymax%22%3A38.2%2C%22spatialReference%22%3A%7B%22wkid%22%3A4326%7D%7D&geometryType=esriGeometryEnvelope&spatialRel=esriSpatialRelIntersects&outFields=VOLTAGE%2CTYPE&f=geojson&resultRecordCount=500"

    func fetch() {
        isLoading = true
        errorMessage = nil

        // Check cache first
        let cacheKey = ResponseCache.cacheKey(layer: .electricLines)
        if let cachedData = ResponseCache.shared.get(key: cacheKey, layer: .electricLines) {
            do {
                let geojson = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: cachedData)
                let parsed = Self.parseLines(from: geojson)
                AppLogger.network.info("ElectricLines: loaded \(parsed.count) lines from cache")
                DispatchQueue.main.async {
                    self.lines = parsed.isEmpty ? Self.mockLines() : parsed
                    self.isLoading = false
                }
                return
            } catch {
                AppLogger.network.warning("ElectricLines: cache decode failed, fetching from network")
            }
        }

        guard let url = URL(string: urlString) else { isLoading = false; return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            defer { DispatchQueue.main.async { self?.isLoading = false } }
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self?.errorMessage = "Electric lines API unavailable, using estimates"
                    self?.lines = Self.mockLines()
                }
                return
            }
            do {
                let geojson = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data)
                let parsed = Self.parseLines(from: geojson)
                ResponseCache.shared.set(data: data, key: cacheKey, layer: .electricLines)
                AppLogger.network.info("ElectricLines: fetched \(parsed.count) lines from network")
                DispatchQueue.main.async { self?.lines = parsed.isEmpty ? Self.mockLines() : parsed }
            } catch {
                DispatchQueue.main.async { self?.lines = Self.mockLines() }
            }
        }.resume()
    }

    // MARK: - Parsing

    private static func parseLines(from geojson: GeoJSONFeatureCollection) -> [ElectricLine] {
        geojson.features.compactMap { feature -> ElectricLine? in
            guard let coords = feature.geometry.coordinates else { return nil }
            let points = coords.compactMap { c -> CLLocationCoordinate2D? in
                guard c.count >= 2 else { return nil }
                return CLLocationCoordinate2D(latitude: c[1], longitude: c[0])
            }
            guard !points.isEmpty else { return nil }
            let voltage = feature.properties.voltage ?? 0
            return ElectricLine(coordinates: points, voltage: voltage, type: feature.properties.type ?? "AC")
        }
    }

    static func mockLines() -> [ElectricLine] {
        // Approximate PG&E 115kV and 60kV transmission corridors in South Bay
        return [
            ElectricLine(coordinates: [
                CLLocationCoordinate2D(latitude: 37.48, longitude: -122.05),
                CLLocationCoordinate2D(latitude: 37.44, longitude: -121.97),
                CLLocationCoordinate2D(latitude: 37.39, longitude: -121.92),
            ], voltage: 115, type: "AC"),
            ElectricLine(coordinates: [
                CLLocationCoordinate2D(latitude: 37.51, longitude: -122.02),
                CLLocationCoordinate2D(latitude: 37.46, longitude: -121.98),
                CLLocationCoordinate2D(latitude: 37.42, longitude: -121.95),
                CLLocationCoordinate2D(latitude: 37.37, longitude: -121.90),
            ], voltage: 115, type: "AC"),
            ElectricLine(coordinates: [
                CLLocationCoordinate2D(latitude: 37.42, longitude: -122.08),
                CLLocationCoordinate2D(latitude: 37.38, longitude: -122.05),
                CLLocationCoordinate2D(latitude: 37.35, longitude: -122.01),
            ], voltage: 60, type: "AC"),
            ElectricLine(coordinates: [
                CLLocationCoordinate2D(latitude: 37.50, longitude: -121.98),
                CLLocationCoordinate2D(latitude: 37.47, longitude: -121.95),
                CLLocationCoordinate2D(latitude: 37.44, longitude: -121.91),
            ], voltage: 115, type: "AC"),
        ]
    }

    // MARK: - Decodable
    struct GeoJSONFeatureCollection: Decodable {
        let features: [Feature]
    }
    struct Feature: Decodable {
        let geometry: Geometry
        let properties: Properties
    }
    struct Geometry: Decodable {
        let coordinates: [[Double]]?
        private enum CodingKeys: String, CodingKey { case coordinates }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            coordinates = try? c.decode([[Double]].self, forKey: .coordinates)
        }
    }
    struct Properties: Decodable {
        let voltage: Int?
        let type: String?
        private enum CodingKeys: String, CodingKey { case voltage = "VOLTAGE"; case type = "TYPE" }
    }
}
