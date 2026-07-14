import Foundation
import AMapsDomain

#if canImport(CoreMotion)
import CoreMotion

/// Bridges CoreMotion's activity classifier to the domain `ActivityType`, so a
/// ride can auto-switch between walking / cycling / driving without the user
/// tapping anything. Stationary/unknown samples are ignored — we keep the last
/// real mode rather than flapping.
public final class ActivityDetector {
    private let manager = CMMotionActivityManager()

    /// Fired on the main queue when a confident new activity is detected.
    public var onChange: ((ActivityType) -> Void)?

    public init() {}

    /// CoreMotion activity is unavailable on Simulator and on devices without
    /// the motion coprocessor — callers should fall back to a manual mode.
    public static var isAvailable: Bool { CMMotionActivityManager.isActivityAvailable() }

    public func start() {
        guard Self.isAvailable else { return }
        manager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity, activity.confidence != .low else { return }
            let type: ActivityType
            if activity.cycling { type = .cycling }
            else if activity.automotive { type = .automotive }
            else if activity.walking || activity.running { type = .walking }
            else { return }   // stationary / unknown → keep the current mode
            self.onChange?(type)
        }
    }

    public func stop() {
        guard Self.isAvailable else { return }
        manager.stopActivityUpdates()
    }
}
#endif
