import Testing
import Foundation
@testable import AMapsDomain
@testable import AMapsFog
@testable import AMapsTracking

@Suite struct FogEngineTests {
    let grid = SlippyGrid(zoom: 17)

    @Test func opensNewCellOnce() {
        let fog = FogEngine(grid: grid)
        let here = Coordinate(latitude: 21.0278, longitude: 105.8342) // Hanoi
        #expect(fog.observe(here, at: .now, activity: .cycling) != nil)
        #expect(fog.observe(here, at: .now, activity: .cycling) == nil)
        #expect(fog.visitedCount == 1)
    }

    @Test func mergeIsConflictFree() {
        let a = FogEngine(grid: grid)
        let c = Coordinate(latitude: 21.03, longitude: 105.85)
        let cell = a.observe(c, at: .now, activity: .walking)!
        let b = FogEngine(grid: grid)
        b.merge([cell])
        b.merge([cell]) // idempotent
        #expect(b.visitedCount == 1)
    }

    @Test func coverageFraction() {
        let fog = FogEngine(grid: grid)
        let c1 = Coordinate(latitude: 21.0, longitude: 105.0)
        let c2 = Coordinate(latitude: 21.0, longitude: 105.01)
        let cell1 = grid.cell(for: c1)
        let cell2 = grid.cell(for: c2)
        fog.observe(c1, at: .now, activity: .cycling)
        #expect(fog.coverage(ofCityCells: [cell1, cell2]) == 0.5)
    }
}

@Suite struct SessionRecorderTests {
    @Test func rejectsInaccurateFixes() {
        let fog = FogEngine(grid: SlippyGrid())
        let rec = SessionRecorder(session: Session(startedAt: .now, activity: .cycling), fog: fog)
        let bad = TrackPoint(coordinate: .init(latitude: 21, longitude: 105),
                             timestamp: .now, speedMetersPerSecond: 5, horizontalAccuracy: 500)
        #expect(rec.ingest(bad) == false)
    }

    @Test func accumulatesDistance() {
        let fog = FogEngine(grid: SlippyGrid())
        let rec = SessionRecorder(session: Session(startedAt: .now, activity: .cycling), fog: fog)
        let t = Date()
        rec.ingest(TrackPoint(coordinate: .init(latitude: 21.0, longitude: 105.0),
                              timestamp: t, speedMetersPerSecond: 5, horizontalAccuracy: 5))
        rec.ingest(TrackPoint(coordinate: .init(latitude: 21.001, longitude: 105.0),
                              timestamp: t.addingTimeInterval(30), speedMetersPerSecond: 5,
                              horizontalAccuracy: 5))
        #expect(rec.session.distanceMeters > 100)
    }
}
