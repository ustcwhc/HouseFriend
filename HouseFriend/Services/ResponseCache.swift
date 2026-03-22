import Foundation
import os

/// Per-layer TTL configuration for cached API responses.
enum CacheLayer: String, CaseIterable {
    case earthquake
    case airQuality
    case crime
    case electricLines
    case noise
    case bundled

    /// TTL in seconds. nil means never expires.
    var ttl: TimeInterval? {
        switch self {
        case .earthquake:    return 1_800    // 30 minutes
        case .airQuality:    return 3_600    // 1 hour
        case .crime:         return 86_400   // 24 hours
        case .electricLines: return 86_400   // 24 hours (same as crime — static infrastructure)
        case .noise:         return nil       // bundled roads never expire
        case .bundled:       return nil       // never expires
        }
    }
}

// MARK: - Cache entry wrapper

/// Wraps cached data with metadata for expiry checks.
private class CacheEntry: NSObject {
    let data: Data
    let storedAt: Date
    let layer: CacheLayer

    init(data: Data, storedAt: Date, layer: CacheLayer) {
        self.data = data
        self.storedAt = storedAt
        self.layer = layer
    }
}

/// Disk metadata sidecar (JSON-encoded alongside raw data).
private struct CacheMetadata: Codable {
    let storedAt: TimeInterval  // timeIntervalSince1970
    let layer: String           // CacheLayer.rawValue
}

// MARK: - ResponseCache

/// Two-level cache: NSCache (memory) + FileManager (disk).
/// Thread-safe for reads/writes via serial queue.
final class ResponseCache {

    static let shared = ResponseCache()

    private let memoryCache = NSCache<NSString, CacheEntry>()
    private let fileManager = FileManager.default
    private let diskCacheURL: URL
    private let dateProvider: () -> Date
    private let ioQueue = DispatchQueue(label: "com.housefriend.responsecache.io")

    init(dateProvider: @escaping () -> Date = { Date() }) {
        self.dateProvider = dateProvider

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.diskCacheURL = caches.appendingPathComponent("ResponseCache")

        // Create disk cache directory if needed
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        memoryCache.countLimit = 50
    }

    // MARK: - Public API

    /// Retrieves cached data for a key+layer. Returns nil on miss or expiry.
    func get(key: String, layer: CacheLayer) -> Data? {
        // Memory-first lookup
        let nsKey = key as NSString
        if let entry = memoryCache.object(forKey: nsKey) {
            if isValid(entry: entry) {
                AppLogger.network.info("Cache HIT [\(layer.rawValue)] key=\(key)")
                return entry.data
            } else {
                memoryCache.removeObject(forKey: nsKey)
            }
        }

        // Disk fallback
        if let (data, metadata) = readFromDisk(key: key) {
            guard let diskLayer = CacheLayer(rawValue: metadata.layer) else {
                AppLogger.network.info("Cache MISS [\(layer.rawValue)] key=\(key)")
                return nil
            }
            let storedDate = Date(timeIntervalSince1970: metadata.storedAt)
            let entry = CacheEntry(data: data, storedAt: storedDate, layer: diskLayer)

            if isValid(entry: entry) {
                // Promote back to memory
                memoryCache.setObject(entry, forKey: nsKey)
                AppLogger.network.info("Cache HIT [\(layer.rawValue)] key=\(key)")
                return data
            } else {
                // Expired — clean up disk
                removeDisk(key: key)
            }
        }

        AppLogger.network.info("Cache MISS [\(layer.rawValue)] key=\(key)")
        return nil
    }

    /// Stores data in both memory and disk caches.
    func set(data: Data, key: String, layer: CacheLayer) {
        let now = dateProvider()
        let entry = CacheEntry(data: data, storedAt: now, layer: layer)

        // Memory
        memoryCache.setObject(entry, forKey: key as NSString)

        // Disk
        writeToDisk(data: data, key: key, storedAt: now, layer: layer)
    }

    /// Clears the in-memory cache (for testing and memory pressure).
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }

    /// Clears all cached data (memory + disk) for a specific layer.
    func clearLayer(_ layer: CacheLayer) {
        memoryCache.removeAllObjects()
        // Remove disk files matching this layer
        if let files = try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: nil) {
            for file in files where file.lastPathComponent.hasPrefix(layer.rawValue) {
                try? fileManager.removeItem(at: file)
            }
        }
        AppLogger.network.info("Cache cleared for layer: \(layer.rawValue)")
    }

    // MARK: - Cache key generation

    /// Location-based cache key quantized to 0.01-degree grid cells.
    static func cacheKey(layer: CacheLayer, lat: Double, lon: Double) -> String {
        "\(layer.rawValue)_\(String(format: "%.2f", lat))_\(String(format: "%.2f", lon))"
    }

    /// Non-location cache key for global/singleton data.
    static func cacheKey(layer: CacheLayer) -> String {
        "\(layer.rawValue)_global"
    }

    // MARK: - Private helpers

    private func isValid(entry: CacheEntry) -> Bool {
        guard let ttl = entry.layer.ttl else {
            return true // nil TTL = never expires
        }
        let elapsed = dateProvider().timeIntervalSince(entry.storedAt)
        return elapsed <= ttl
    }

    private func diskDataURL(key: String) -> URL {
        diskCacheURL.appendingPathComponent("\(key).data")
    }

    private func diskMetaURL(key: String) -> URL {
        diskCacheURL.appendingPathComponent("\(key).meta")
    }

    private func writeToDisk(data: Data, key: String, storedAt: Date, layer: CacheLayer) {
        let dataURL = diskDataURL(key: key)
        let metaURL = diskMetaURL(key: key)

        let metadata = CacheMetadata(
            storedAt: storedAt.timeIntervalSince1970,
            layer: layer.rawValue
        )

        try? data.write(to: dataURL)
        if let metaData = try? JSONEncoder().encode(metadata) {
            try? metaData.write(to: metaURL)
        }
    }

    private func readFromDisk(key: String) -> (Data, CacheMetadata)? {
        let dataURL = diskDataURL(key: key)
        let metaURL = diskMetaURL(key: key)

        guard let data = try? Data(contentsOf: dataURL),
              let metaData = try? Data(contentsOf: metaURL),
              let metadata = try? JSONDecoder().decode(CacheMetadata.self, from: metaData) else {
            return nil
        }
        return (data, metadata)
    }

    private func removeDisk(key: String) {
        try? fileManager.removeItem(at: diskDataURL(key: key))
        try? fileManager.removeItem(at: diskMetaURL(key: key))
    }
}
