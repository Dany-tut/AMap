import Foundation
import AMapsApp
import AMapsDomain
import AMapsFog
import AMapsStorage
import AMapsTracking

/// UI-facing state for the map screen. Owns the composition root and drives
/// the live session. Mirrors the web prototype's Danang demo.
@MainActor
final class AppModel: ObservableObject {
    @Published var regionName = "Дананг"
    @Published var coveragePercent = 15
    @Published var cellCount = 0
    @Published var riding = false

    /// Danang waterfront — same demo center as the web prototype.
    let center = Coordinate(latitude: 16.0678, longitude: 108.2208)

    let composition: AppComposition
    private var recorder: SessionRecorder?

    init() {
        do {
            composition = try AppComposition()
        } catch {
            // InMemoryStore never throws on load; fall back to an empty engine.
            composition = try! AppComposition(store: InMemoryStore())
        }
        cellCount = composition.fog.visitedCount
    }

    func toggleRide() {
        riding ? stopRide() : startRide()
    }

    private func startRide() {
        recorder = composition.startSession(activity: .cycling)
        riding = true
    }

    private func stopRide() {
        _ = recorder?.finish()
        recorder = nil
        riding = false
        cellCount = composition.fog.visitedCount
    }
}
