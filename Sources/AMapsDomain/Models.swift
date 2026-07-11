import Foundation

public enum ActivityType: String, Codable, Sendable, CaseIterable {
    case walking, cycling, automotive, unknown
}

public struct Coordinate: Codable, Sendable, Hashable {
    public let latitude: Double
    public let longitude: Double
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// A recorded outing (a bike ride, a walk, a drive).
public struct Session: Identifiable, Codable, Sendable {
    public let id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var activity: ActivityType
    public var distanceMeters: Double
    public var newCellsOpened: Int

    public init(id: UUID = UUID(), startedAt: Date, endedAt: Date? = nil,
                activity: ActivityType = .unknown, distanceMeters: Double = 0,
                newCellsOpened: Int = 0) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.activity = activity
        self.distanceMeters = distanceMeters
        self.newCellsOpened = newCellsOpened
    }
}

/// A raw GPS fix inside a session.
public struct TrackPoint: Codable, Sendable {
    public let coordinate: Coordinate
    public let timestamp: Date
    public let speedMetersPerSecond: Double
    public let horizontalAccuracy: Double
    public init(coordinate: Coordinate, timestamp: Date,
                speedMetersPerSecond: Double, horizontalAccuracy: Double) {
        self.coordinate = coordinate
        self.timestamp = timestamp
        self.speedMetersPerSecond = speedMetersPerSecond
        self.horizontalAccuracy = horizontalAccuracy
    }
}

/// One explored grid cell — the fog-of-war "save state".
public struct VisitedCell: Codable, Sendable, Hashable {
    public let index: CellIndex
    public let firstVisitAt: Date
    public let activity: ActivityType
    public init(index: CellIndex, firstVisitAt: Date, activity: ActivityType) {
        self.index = index
        self.firstVisitAt = firstVisitAt
        self.activity = activity
    }
}

/// Opaque grid-cell identifier (backed by an H3 index in production).
public struct CellIndex: Codable, Sendable, Hashable, RawRepresentable {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }
}

public struct Place: Identifiable, Codable, Sendable {
    public let id: UUID
    public var cell: CellIndex
    public var osmID: Int64?
    public var name: String
    public var category: String
    public init(id: UUID = UUID(), cell: CellIndex, osmID: Int64? = nil,
                name: String, category: String) {
        self.id = id
        self.cell = cell
        self.osmID = osmID
        self.name = name
        self.category = category
    }
}

public struct JournalEntry: Identifiable, Codable, Sendable {
    public let id: UUID
    public var placeID: UUID?
    public var sessionID: UUID?
    public var text: String
    public var photoAssetIDs: [String]
    public var createdAt: Date
    public init(id: UUID = UUID(), placeID: UUID? = nil, sessionID: UUID? = nil,
                text: String, photoAssetIDs: [String] = [], createdAt: Date = .now) {
        self.id = id
        self.placeID = placeID
        self.sessionID = sessionID
        self.text = text
        self.photoAssetIDs = photoAssetIDs
        self.createdAt = createdAt
    }
}
