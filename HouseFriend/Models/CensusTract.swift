import Foundation
import MapKit
import Compression

// MARK: - CensusTract

/// A Census Tract boundary polygon for fine-grained crime density rendering.
/// Bay Area has ~1,772 tracts — much smaller than ZIPs, follows street-level boundaries.
struct CensusTract: Identifiable {
    let id: String                          // FIPS GEOID (e.g., "06075010100")
    let name: String                        // Human-readable (e.g., "Census Tract 101")
    let county: String                      // County FIPS code
    let polygon: [CLLocationCoordinate2D]   // Boundary coordinates
    let center: CLLocationCoordinate2D      // Centroid for quick distance checks
}

// MARK: - Loader

struct CensusTractData {
    /// Loads bayarea_tracts.json.gz from the app bundle at runtime.
    static func allTracts() -> [CensusTract] {
        guard let url = Bundle.main.url(forResource: "bayarea_tracts.json", withExtension: "gz"),
              let compressed = try? Data(contentsOf: url),
              let decompressed = gunzip(compressed) else {
            AppLogger.network.error("CensusTract: failed to load bayarea_tracts.json.gz")
            return []
        }

        guard let raw = try? JSONSerialization.jsonObject(with: decompressed) as? [[String: Any]] else {
            AppLogger.network.error("CensusTract: failed to parse JSON")
            return []
        }

        let tracts = raw.compactMap { parseTract($0) }
        AppLogger.network.info("CensusTract: loaded \(tracts.count) tracts from bundle")
        return tracts
    }

    private static func parseTract(_ d: [String: Any]) -> CensusTract? {
        guard let id = d["id"] as? String,
              let name = d["name"] as? String,
              let county = d["county"] as? String,
              let poly = d["polygon"] as? [[Double]],
              let ctr = d["center"] as? [Double],
              ctr.count == 2 else { return nil }

        let polygon = poly.compactMap { pt -> CLLocationCoordinate2D? in
            guard pt.count == 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pt[1], longitude: pt[0])
        }
        guard polygon.count >= 4 else { return nil }

        let center = CLLocationCoordinate2D(latitude: ctr[1], longitude: ctr[0])
        return CensusTract(id: id, name: name, county: county, polygon: polygon, center: center)
    }

    // MARK: - Gzip decompression (same approach as NoiseService)

    /// Public accessor for gzip decompression (used by CrimeService for bundled data)
    static func gunzipPublic(_ data: Data) -> Data? {
        return gunzip(data)
    }

    private static func gunzip(_ data: Data) -> Data? {
        guard data.count > 18 else { return nil }
        // Skip gzip header to get raw deflate stream
        var headerLen = 10
        let flags = data[3]
        if flags & 0x04 != 0 { // FEXTRA
            guard data.count > headerLen + 2 else { return nil }
            headerLen += 2 + Int(data[headerLen]) + Int(data[headerLen + 1]) << 8
        }
        if flags & 0x08 != 0 { // FNAME
            while headerLen < data.count && data[headerLen] != 0 { headerLen += 1 }
            headerLen += 1
        }
        if flags & 0x10 != 0 { // FCOMMENT
            while headerLen < data.count && data[headerLen] != 0 { headerLen += 1 }
            headerLen += 1
        }
        if flags & 0x02 != 0 { headerLen += 2 } // FHCRC

        let deflated = data.subdata(in: headerLen..<(data.count - 8))
        let bufferSize = 16 * 1024 * 1024 // 16 MB (tract data is larger than roads)
        var output = Data(count: bufferSize)
        let decoded = output.withUnsafeMutableBytes { outPtr -> Int in
            deflated.withUnsafeBytes { inPtr -> Int in
                let out = outPtr.bindMemory(to: UInt8.self)
                let inp = inPtr.bindMemory(to: UInt8.self)
                return compression_decode_buffer(
                    out.baseAddress!, bufferSize,
                    inp.baseAddress!, deflated.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        guard decoded > 0 else { return nil }
        output.count = decoded
        return output
    }
}
