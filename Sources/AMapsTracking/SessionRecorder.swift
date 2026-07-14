import Foundation
import AMapsDomain
import AMapsFog

/// Filters incoming GPS fixes and accumulates live session statistics.
/// Kept free of CoreLocation so it can be unit-tested with synthetic points;
/// the CLLocationManager bridge lives in the app target.
public final class SessionRecorder {
    public private(set) var session: Session
    private let fog: FogEngine
    private var lastAccepted: TrackPoint?

    public var maxHorizontalAccuracy: Double = 50   // metres
    public var maxPlausibleSpeed: Double = 70       // m/s (~250 km/h) outlier guard

    public init(session: Session, fog: FogEngine) {
        self.session = session
        self.fog = fog
    }

    /// Ingest a fix. Rejects outliers, updates distance, and opens fog cells.
    /// Returns true if the point was accepted.
    @discardableResult
    public func ingest(_ point: TrackPoint) -> Bool {
        guard point.horizontalAccuracy <= maxHorizontalAccuracy,
              point.horizontalAccuracy >= 0 else { return false }

        if let last = lastAccepted {
            let d = haversine(last.coordinate, point.coordinate)
            let dt = point.timestamp.timeIntervalSince(last.timestamp)
            if dt > 0, d / dt > maxPlausibleSpeed { return false }
            session.distanceMeters += d
        }

        if fog.observe(point.coordinate, at: point.timestamp,
                       activity: session.activity) != nil {
            session.newCellsOpened += 1
        }
        lastAccepted = point
        return true
    }

    /// Update the active mode mid-session (e.g. CoreMotion auto-detect switching
    /// from walking to cycling). New cells are tagged with the latest activity.
    public func setActivity(_ activity: ActivityType) {
        session.activity = activity
    }

    public func finish(at time: Date = .now) -> Session {
        session.endedAt = time
        return session
    }
}

func haversine(_ a: Coordinate, _ b: Coordinate) -> Double {
    let r = 6_371_000.0
    let dLat = (b.latitude - a.latitude) * .pi / 180
    let dLon = (b.longitude - a.longitude) * .pi / 180
    let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
    let h = sin(dLat / 2) * sin(dLat / 2)
        + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
    return 2 * r * asin(min(1, sqrt(h)))
}
