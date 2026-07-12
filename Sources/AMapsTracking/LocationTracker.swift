import Foundation
import AMapsDomain

#if canImport(CoreLocation)
import CoreLocation

/// Bridges CLLocationManager to the platform-agnostic `SessionRecorder`.
///
/// Runs in one of three modes to balance battery against fidelity:
///  - `.passive`  — visits + significant-change monitoring, near-zero battery.
///                  Feeds "you were somewhere new" prompts.
///  - `.active`   — full GPS during a recorded outing (background updates on).
///  - `.off`      — nothing running.
///
/// Mode is driven by the app (manual start, or CoreMotion activity auto-detect).
public final class LocationTracker: NSObject, CLLocationManagerDelegate {
    public enum Mode { case off, passive, active }

    private let manager = CLLocationManager()
    private var recorder: SessionRecorder?

    /// Fired when a recorded fix opens new ground (drives achievements + reveal).
    public var onNewCells: ((Int) -> Void)?
    /// Fired in passive mode when the user lingers somewhere (drives place prompts).
    public var onVisit: ((Coordinate, Date) -> Void)?

    public private(set) var mode: Mode = .off

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = true
    }

    /// Ask for When-In-Use first; upgrade to Always only when enabling passive
    /// mode, with an explaining screen shown by the app beforehand.
    public func requestWhenInUse() { manager.requestWhenInUseAuthorization() }
    public func requestAlways() { manager.requestAlwaysAuthorization() }

    public func startPassive() {
        mode = .passive
        manager.startMonitoringVisits()
        manager.startMonitoringSignificantLocationChanges()
    }

    public func startActive(recorder: SessionRecorder) {
        self.recorder = recorder
        mode = .active
        manager.allowsBackgroundLocationUpdates = true
        manager.startUpdatingLocation()
    }

    public func stopActive() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        recorder = nil
        mode = mode == .active ? .off : mode
    }

    // MARK: CLLocationManagerDelegate

    public func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let recorder else { return }
        var opened = 0
        for loc in locs {
            let p = TrackPoint(
                coordinate: Coordinate(latitude: loc.coordinate.latitude,
                                       longitude: loc.coordinate.longitude),
                timestamp: loc.timestamp,
                speedMetersPerSecond: max(0, loc.speed),
                horizontalAccuracy: loc.horizontalAccuracy)
            let before = recorder.session.newCellsOpened
            recorder.ingest(p)
            opened += recorder.session.newCellsOpened - before
        }
        if opened > 0 { onNewCells?(opened) }
    }

    public func locationManager(_ m: CLLocationManager, didVisit visit: CLVisit) {
        guard visit.departureDate == Date.distantFuture else { return } // arrival only
        onVisit?(Coordinate(latitude: visit.coordinate.latitude,
                            longitude: visit.coordinate.longitude), visit.arrivalDate)
    }
}
#endif
