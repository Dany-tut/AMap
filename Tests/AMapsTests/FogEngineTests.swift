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

@Suite struct FogGeoJSONTests {
    let grid = SlippyGrid(zoom: 17)

    @Test func emitsClosedPolygonPerCell() throws {
        let fog = FogEngine(grid: grid)
        let c = Coordinate(latitude: 21.0278, longitude: 105.8342)
        fog.observe(c, at: .now, activity: .cycling)
        let json = FogGeoJSON(grid: grid).featureCollection(for: fog.allVisited())
        let features = json["features"] as! [[String: Any]]
        #expect(features.count == 1)
        let geom = features[0]["geometry"] as! [String: Any]
        let ring = (geom["coordinates"] as! [[[Double]]])[0]
        #expect(ring.count == 5)          // 4 corners + closing point
        #expect(ring.first! == ring.last!) // ring is closed
    }

    @Test func viewportFiltersDistantCells() {
        let fog = FogEngine(grid: grid)
        fog.observe(Coordinate(latitude: 21.0, longitude: 105.0), at: .now, activity: .walking)
        fog.observe(Coordinate(latitude: 51.5, longitude: -0.12), at: .now, activity: .walking)
        let hanoiBox = BoundingBox(minLat: 20.9, minLon: 104.9, maxLat: 21.1, maxLon: 105.1)
        let json = FogGeoJSON(grid: grid).featureCollection(for: fog.allVisited(), within: hanoiBox)
        #expect((json["features"] as! [[String: Any]]).count == 1)
    }

    @Test func polygonRoundTripsNearOrigin() {
        let c = Coordinate(latitude: 21.0278, longitude: 105.8342)
        let ring = grid.polygon(for: grid.cell(for: c))
        // The originating point must fall inside the returned tile bounds.
        let lats = ring.map(\.latitude), lons = ring.map(\.longitude)
        #expect(c.latitude <= lats.max()! && c.latitude >= lats.min()!)
        #expect(c.longitude >= lons.min()! && c.longitude <= lons.max()!)
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
