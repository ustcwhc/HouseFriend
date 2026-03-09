import os

/// Centralized loggers for HouseFriend subsystems.
/// Usage: AppLogger.network.error("Failed to fetch: \(error)")
enum AppLogger {
    static let network  = Logger(subsystem: "com.housefriend", category: "network")
    static let scoring  = Logger(subsystem: "com.housefriend", category: "scoring")
    static let location = Logger(subsystem: "com.housefriend", category: "location")
    static let map      = Logger(subsystem: "com.housefriend", category: "map")
}
