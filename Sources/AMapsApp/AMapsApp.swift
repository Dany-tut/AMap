import Foundation
import AMapsDomain
import AMapsFog
import AMapsTracking
import AMapsStorage

/// Composition root. In the Xcode app this is wired into a SwiftUI `App`;
/// here it documents how the layers connect and gives the package an
/// executable-free entry surface for the SPM build.
public struct AppComposition {
    public let store: Store
    public let fog: FogEngine

    public init(store: Store = InMemoryStore(),
                grid: GridProjection = SlippyGrid()) throws {
        self.store = store
        let existing = try store.loadVisitedCells()
        self.fog = FogEngine(grid: grid, existing: existing)
    }

    public func startSession(activity: ActivityType) -> SessionRecorder {
        let session = Session(startedAt: .now, activity: activity)
        return SessionRecorder(session: session, fog: fog)
    }
}
