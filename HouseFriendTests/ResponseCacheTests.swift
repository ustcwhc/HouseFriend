import Testing
import Foundation
@testable import HouseFriend

struct ResponseCacheTests {

    // MARK: - Cache miss / hit basics

    @Test func getMissForUnknownKey() {
        let cache = ResponseCache(dateProvider: { Date() })
        let result = cache.get(key: "nonexistent", layer: .earthquake)
        #expect(result == nil)
    }

    @Test func setThenGetReturnsCachedData() {
        let cache = ResponseCache(dateProvider: { Date() })
        let data = Data("hello".utf8)
        cache.set(data: data, key: "test_key", layer: .earthquake)
        let result = cache.get(key: "test_key", layer: .earthquake)
        #expect(result == data)
    }

    // MARK: - TTL expiry per layer

    @Test func earthquakeExpiresAfter30Minutes() {
        var now = Date()
        let cache = ResponseCache(dateProvider: { now })
        let data = Data("quake".utf8)
        cache.set(data: data, key: "eq_key", layer: .earthquake)

        // Advance time past 30 min TTL
        now = now.addingTimeInterval(1801)
        let result = cache.get(key: "eq_key", layer: .earthquake)
        #expect(result == nil)
    }

    @Test func airQualityValidBeforeExpiry() {
        var now = Date()
        let cache = ResponseCache(dateProvider: { now })
        let data = Data("air".utf8)
        cache.set(data: data, key: "aq_key", layer: .airQuality)

        // Advance time to just before 1 hour
        now = now.addingTimeInterval(3599)
        let result = cache.get(key: "aq_key", layer: .airQuality)
        #expect(result == data)
    }

    @Test func crimeValidBeforeExpiry() {
        var now = Date()
        let cache = ResponseCache(dateProvider: { now })
        let data = Data("crime".utf8)
        cache.set(data: data, key: "cr_key", layer: .crime)

        // Advance time to just before 24 hours
        now = now.addingTimeInterval(86399)
        let result = cache.get(key: "cr_key", layer: .crime)
        #expect(result == data)
    }

    @Test func bundledNeverExpires() {
        var now = Date()
        let cache = ResponseCache(dateProvider: { now })
        let data = Data("bundled".utf8)
        cache.set(data: data, key: "b_key", layer: .bundled)

        // Advance time by 1 year
        now = now.addingTimeInterval(365 * 86400)
        let result = cache.get(key: "b_key", layer: .bundled)
        #expect(result == data)
    }

    // MARK: - Disk fallback

    @Test func diskFallbackAfterMemoryClear() {
        let cache = ResponseCache(dateProvider: { Date() })
        let data = Data("persist".utf8)
        cache.set(data: data, key: "disk_key", layer: .earthquake)

        cache.clearMemoryCache()

        let result = cache.get(key: "disk_key", layer: .earthquake)
        #expect(result == data)
    }

    // MARK: - TTL values

    @Test func earthquakeTTLIs1800() {
        #expect(CacheLayer.earthquake.ttl == 1800)
    }

    @Test func airQualityTTLIs3600() {
        #expect(CacheLayer.airQuality.ttl == 3600)
    }

    @Test func crimeTTLIs86400() {
        #expect(CacheLayer.crime.ttl == 86400)
    }

    @Test func bundledTTLIsNil() {
        #expect(CacheLayer.bundled.ttl == nil)
    }

    // MARK: - Cache key generation

    @Test func cacheKeySameGridCellReturnsSameKey() {
        let key1 = ResponseCache.cacheKey(layer: .earthquake, lat: 37.7749, lon: -122.4194)
        let key2 = ResponseCache.cacheKey(layer: .earthquake, lat: 37.7740, lon: -122.4190)
        #expect(key1 == key2)

        let key3 = ResponseCache.cacheKey(layer: .earthquake, lat: 37.80, lon: -122.42)
        #expect(key1 != key3)
    }
}
