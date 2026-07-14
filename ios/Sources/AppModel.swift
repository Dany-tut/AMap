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
    /// Auto-detected mode for the current ride (CoreMotion).
    @Published var activity: ActivityType = .cycling

    /// Interior rings (open cells) that punch holes in the cloud layer.
    @Published var fogHoles: [[Coordinate]] = []

    /// Danang waterfront — same demo center as the web prototype.
    let center = Coordinate(latitude: 16.0678, longitude: 108.2208)

    /// Cloud exterior: a generous box around the demo city.
    let fogOuter: [Coordinate]

    let composition: AppComposition
    private var recorder: SessionRecorder?

    private let tracker = LocationTracker()
    private let activityDetector = ActivityDetector()
    /// Path revealed during the current/last live ride.
    private var liveRoute: [Coordinate] = []
    /// The seeded demo corridor ring, always shown as a base reveal.
    private let demoCorridor: [Coordinate]

    init() {
        let c = Coordinate(latitude: 16.0678, longitude: 108.2208)
        let pad = 0.09
        fogOuter = [
            Coordinate(latitude: c.latitude - pad, longitude: c.longitude - pad),
            Coordinate(latitude: c.latitude - pad, longitude: c.longitude + pad),
            Coordinate(latitude: c.latitude + pad, longitude: c.longitude + pad),
            Coordinate(latitude: c.latitude + pad, longitude: c.longitude - pad),
        ]

        let g = SlippyGrid()
        composition = (try? AppComposition(store: InMemoryStore(), grid: g))
            ?? { fatalError("composition failed to build") }()

        // Visual reveal = a smooth corridor ribbon along the route (like the web
        // prototype); cells drive the counter, the ribbon drives the look.
        demoCorridor = Self.corridor(along: Self.demoRoute, radiusMeters: 70)
        seedDemoCorridor()
        fogHoles = [demoCorridor]
        cellCount = composition.fog.visitedCount

        tracker.onFix = { [weak self] coord, _ in
            MainActor.assumeIsolated { self?.appendLiveFix(coord) }
        }
        activityDetector.onChange = { [weak self] activity in
            MainActor.assumeIsolated { self?.applyActivity(activity) }
        }
    }

    /// CoreMotion reported a new mode — tag future cells and reflect it in the UI.
    private func applyActivity(_ a: ActivityType) {
        activity = a
        recorder?.setActivity(a)
    }

    /// Manual override / demo fallback (CoreMotion is unavailable on Simulator).
    func cycleActivity() {
        let order: [ActivityType] = [.walking, .cycling, .automotive]
        let i = order.firstIndex(of: activity) ?? 1
        applyActivity(order[(i + 1) % order.count])
    }

    func toggleRide() {
        riding ? stopRide() : startRide()
    }

    private func startRide() {
        let recorder = composition.startSession(activity: activity)
        self.recorder = recorder
        liveRoute = []
        riding = true
        tracker.requestWhenInUse()
        tracker.startActive(recorder: recorder)
        activityDetector.start()
    }

    private func stopRide() {
        tracker.stopActive()
        activityDetector.stop()
        _ = recorder?.finish()
        recorder = nil
        riding = false
        cellCount = composition.fog.visitedCount
    }

    /// A live fix arrived — extend the revealed corridor and refresh counters.
    private func appendLiveFix(_ coord: Coordinate) {
        liveRoute.append(coord)
        rebuildHoles()
        cellCount = composition.fog.visitedCount
    }

    private func rebuildHoles() {
        var holes = [demoCorridor]
        if liveRoute.count >= 2 {
            holes.append(Self.corridor(along: liveRoute, radiusMeters: 70))
        }
        fogHoles = holes
    }

    /// Demo route along the Danang waterfront (same idea as the web prototype).
    static let demoRoute: [Coordinate] = [
        .init(latitude: 16.0761, longitude: 108.2246),
        .init(latitude: 16.0712, longitude: 108.2249),
        .init(latitude: 16.0666, longitude: 108.2241),
        .init(latitude: 16.0621, longitude: 108.2231),
        .init(latitude: 16.0586, longitude: 108.2212),
    ]

    /// Opens the cells the demo route passes through so the counter is real.
    private func seedDemoCorridor() {
        var t = Date(timeIntervalSince1970: 1_700_000_000)
        let route = Self.demoRoute
        for i in 0..<(route.count - 1) {
            let a = route[i], b = route[i + 1]
            let steps = 60
            for s in 0...steps {
                let f = Double(s) / Double(steps)
                let p = Coordinate(
                    latitude: a.latitude + (b.latitude - a.latitude) * f,
                    longitude: a.longitude + (b.longitude - a.longitude) * f)
                composition.fog.observe(p, at: t, activity: .cycling)
                t = t.addingTimeInterval(5)
            }
        }
    }

    /// Turns a polyline into a filled ribbon (a single ring) — offsets each
    /// vertex left/right by `radiusMeters` along the averaged segment normal,
    /// then walks the left side forward and the right side back.
    static func corridor(along route: [Coordinate], radiusMeters r: Double) -> [Coordinate] {
        guard route.count >= 2 else { return [] }
        let mPerLat = 111_320.0

        // Unit left-normals per segment, in metres space.
        var segN: [(x: Double, y: Double)] = []
        for i in 0..<(route.count - 1) {
            let a = route[i], b = route[i + 1]
            let midLat = (a.latitude + b.latitude) / 2
            let mPerLon = mPerLat * cos(midLat * .pi / 180)
            let vx = (b.longitude - a.longitude) * mPerLon
            let vy = (b.latitude - a.latitude) * mPerLat
            let len = max(hypot(vx, vy), 1e-6)
            segN.append((x: -vy / len, y: vx / len))   // left normal
        }

        func vertexNormal(_ i: Int) -> (x: Double, y: Double) {
            if i == 0 { return segN[0] }
            if i == route.count - 1 { return segN[segN.count - 1] }
            let a = segN[i - 1], b = segN[i]
            let nx = a.x + b.x, ny = a.y + b.y
            let len = max(hypot(nx, ny), 1e-6)
            return (x: nx / len, y: ny / len)
        }

        func offset(_ p: Coordinate, _ n: (x: Double, y: Double), _ sign: Double) -> Coordinate {
            let mPerLon = mPerLat * cos(p.latitude * .pi / 180)
            return Coordinate(
                latitude: p.latitude + sign * n.y * r / mPerLat,
                longitude: p.longitude + sign * n.x * r / mPerLon)
        }

        var left: [Coordinate] = [], right: [Coordinate] = []
        for i in 0..<route.count {
            let n = vertexNormal(i)
            left.append(offset(route[i], n, +1))
            right.append(offset(route[i], n, -1))
        }
        return left + right.reversed()
    }
}
