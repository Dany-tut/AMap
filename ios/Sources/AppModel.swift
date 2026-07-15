import Foundation
import AMapsApp
import AMapsDomain
import AMapsFog
import AMapsStorage
import AMapsTracking

/// A switchable demo city.
struct DemoRegion: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let center: Coordinate
    let coverage: Int
}

/// A notable spot the ride can pass near, triggering the "new place" card.
struct DemoPlace: Identifiable {
    let id: String
    let name: String
    let category: String
    let emoji: String
    let coord: Coordinate
}

/// A UI-facing journal memory (photo and/or note attached to a place). Mirrors
/// the domain `JournalEntry`, which is also persisted through the store.
struct Memory: Identifiable {
    let id = UUID()
    let placeName: String
    let emoji: String
    let category: String
    let note: String?
    let photo: Data?
    let createdAt: Date
}

/// UI-facing state for the map screen. Owns the composition root and drives
/// the live session. Mirrors the web prototype's Danang demo.
@MainActor
final class AppModel: ObservableObject {
    /// Downloadable regions (bbox/fog are demo-only for now; only Danang is
    /// explored). Real bbox comes from Nominatim/OSM later.
    static let regions: [DemoRegion] = [
        .init(id: "danang", name: "Дананг", emoji: "🏖",
              center: .init(latitude: 16.0678, longitude: 108.2208), coverage: 15),
        .init(id: "hoian", name: "Хойан", emoji: "🏮",
              center: .init(latitude: 15.8801, longitude: 108.3380), coverage: 0),
        .init(id: "hanoi", name: "Ханой", emoji: "🏛",
              center: .init(latitude: 21.0278, longitude: 105.8342), coverage: 0),
        .init(id: "bangkok", name: "Бангкок", emoji: "🛺",
              center: .init(latitude: 13.7563, longitude: 100.5018), coverage: 0),
    ]

    func selectRegion(_ r: DemoRegion) {
        regionName = r.name
        coveragePercent = r.coverage
    }

    // MARK: Trophies (data-driven, evaluated by the core AchievementEngine)

    private static let trophyIcons: [String: String] = [
        "first_cells": "👣", "explorer": "🧭", "cartographer": "🗺️",
        "danang_quarter": "🌇", "streak_3": "🔥", "foodie": "🍜",
    ]

    private static let achievementCatalog: [Achievement] = [
        .init(id: "first_cells", title: "Первые шаги",
              details: "Открой 5 ячеек", condition: .cellsOpened(5)),
        .init(id: "explorer", title: "Исследователь",
              details: "Открой 25 ячеек", condition: .cellsOpened(25)),
        .init(id: "cartographer", title: "Картограф",
              details: "Открой 100 ячеек", condition: .cellsOpened(100)),
        .init(id: "danang_quarter", title: "Свой в Дананге",
              details: "Открой 25% Дананга", condition: .cityCoverage(city: "danang", fraction: 0.25)),
        .init(id: "streak_3", title: "Три дня подряд",
              details: "Катайся 3 дня подряд", condition: .streakDays(3)),
        .init(id: "foodie", title: "Гурман",
              details: "Загляни в кафе", condition: .visitedCategory("food")),
    ]

    var progressSnapshot: ProgressSnapshot {
        ProgressSnapshot(
            totalCellsOpened: cellCount,
            cityCoverage: ["danang": Double(coveragePercent) / 100],
            visitedCategories: [], sessionCount: 0, longestStreakDays: 0)
    }

    var trophies: [TrophyItem] {
        let snap = progressSnapshot
        return Self.achievementCatalog.map { a in
            TrophyItem(id: a.id, icon: Self.trophyIcons[a.id] ?? "🏆",
                       title: a.title, details: a.details,
                       unlocked: a.isSatisfied(by: snap))
        }
    }

    var unlockedTrophyCount: Int { trophies.filter(\.unlocked).count }

    @Published var regionName = "Дананг"
    @Published var coveragePercent = 15
    @Published var cellCount = 0
    @Published var riding = false
    /// Distance covered in the current live ride, in metres (for the ride dock).
    @Published var liveDistanceMeters: Double = 0
    /// Auto-detected mode for the current ride (CoreMotion).
    @Published var activity: ActivityType = .cycling

    /// Interior rings (open cells) that punch holes in the cloud layer.
    @Published var fogHoles: [[Coordinate]] = []

    /// Ride history, newest first. Seeded with a few demo outings; real rides
    /// are prepended when a live session finishes (see `stopRide`).
    @Published var sessions: [Session] = AppModel.demoSessions

    /// Journal memories (photo/note per place), newest first. Seeded with one
    /// demo memory so the journal shows the format before any ride.
    @Published var journal: [Memory] = AppModel.demoJournal

    /// When a live ride passes near a place, this is set and the map presents
    /// the "new place" card; cleared once the user saves or skips it.
    @Published var pendingPlace: DemoPlace?

    /// Places already surfaced this run, so we don't re-prompt for the same spot.
    private var visitedPlaceIDs: Set<String> = []

    /// Danang waterfront — same demo center as the web prototype.
    let center = Coordinate(latitude: 16.0678, longitude: 108.2208)

    let composition: AppComposition
    private var recorder: SessionRecorder?

    private let tracker = LocationTracker()
    private let activityDetector = ActivityDetector()
    /// Path revealed during the current/last live ride.
    private var liveRoute: [Coordinate] = []
    /// The seeded demo corridor ring, always shown as a base reveal.
    private let demoCorridor: [Coordinate]

    init() {
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
        liveDistanceMeters = 0
        riding = true
        tracker.requestWhenInUse()
        tracker.startActive(recorder: recorder)
        activityDetector.start()
    }

    private func stopRide() {
        tracker.stopActive()
        activityDetector.stop()
        if let finished = recorder?.finish(),
           finished.distanceMeters > 0 || finished.newCellsOpened > 0 {
            sessions.insert(finished, at: 0)
        }
        recorder = nil
        riding = false
        cellCount = composition.fog.visitedCount
    }

    /// A live fix arrived — extend the revealed corridor and refresh counters.
    private func appendLiveFix(_ coord: Coordinate) {
        liveRoute.append(coord)
        rebuildHoles()
        cellCount = composition.fog.visitedCount
        if let d = recorder?.session.distanceMeters { liveDistanceMeters = d }
        detectNearbyPlace(coord)
    }

    /// The rider tapped «+ Заметка» — open the place card for an ad-hoc point at
    /// the current location (not one of the seeded spots).
    func addManualPoint() {
        let here = liveRoute.last ?? center
        pendingPlace = DemoPlace(id: "manual-\(journal.count)", name: "Своя точка",
                                 category: "Отметка на маршруте", emoji: "📍", coord: here)
    }

    /// If the ride passes within 90 m of an unseen place, surface its card.
    private func detectNearbyPlace(_ coord: Coordinate) {
        guard pendingPlace == nil else { return }
        for place in Self.demoPlaces where !visitedPlaceIDs.contains(place.id) {
            if Self.distanceMeters(coord, place.coord) < 90 {
                visitedPlaceIDs.insert(place.id)
                pendingPlace = place
                return
            }
        }
    }

    /// Attach a memory (photo and/or note) to the pending place and file it in
    /// the journal — both the UI list and the domain store (persistence path).
    func saveMemory(note: String?, photo: Data?) {
        guard let place = pendingPlace else { return }
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let memory = Memory(
            placeName: place.name, emoji: place.emoji, category: place.category,
            note: (trimmed?.isEmpty == false) ? trimmed : nil,
            photo: photo, createdAt: .now)
        journal.insert(memory, at: 0)

        let assetIDs = photo != nil ? [memory.id.uuidString] : []
        let entry = JournalEntry(text: memory.note ?? "", photoAssetIDs: assetIDs,
                                 createdAt: memory.createdAt)
        try? composition.store.save(entry: entry)

        pendingPlace = nil
    }

    /// Dismiss the card without saving anything.
    func skipPlace() { pendingPlace = nil }

    private func rebuildHoles() {
        var holes = [demoCorridor]
        if liveRoute.count >= 2 {
            holes.append(Self.corridor(along: liveRoute, radiusMeters: 70))
        }
        fogHoles = holes
    }

    // MARK: Profile aggregates (derived from the ride history)

    /// Total distance across all rides, in kilometres.
    var totalKilometers: Double {
        sessions.reduce(0) { $0 + $1.distanceMeters } / 1000
    }

    /// Cells opened total — the fog engine's live visited count is the source
    /// of truth (demo corridor + whatever the current rides have revealed).
    var totalCellsOpened: Int { cellCount }

    var sessionCount: Int { sessions.count }

    /// Longest run of consecutive calendar days that have at least one ride.
    var streakDays: Int {
        let days = Set(sessions.map { Calendar.current.startOfDay(for: $0.startedAt) })
            .sorted(by: >)
        guard let first = days.first else { return 0 }
        var streak = 1
        var prev = first
        for day in days.dropFirst() {
            guard let gap = Calendar.current.dateComponents([.day], from: day, to: prev).day
            else { break }
            if gap == 1 { streak += 1; prev = day } else { break }
        }
        return streak
    }

    /// Distance per activity type, for the profile breakdown.
    func kilometers(for activity: ActivityType) -> Double {
        sessions.filter { $0.activity == activity }
            .reduce(0) { $0 + $1.distanceMeters } / 1000
    }

    /// Seeded ride history so the journal isn't empty on first launch. Dates are
    /// fixed (mid-July 2026) to keep previews and the streak deterministic.
    static let demoSessions: [Session] = {
        func day(_ d: Int, _ h: Int) -> Date {
            DateComponents(calendar: .current, year: 2026, month: 7, day: d,
                           hour: h, minute: 0).date ?? Date(timeIntervalSince1970: 1_752_000_000)
        }
        return [
            Session(startedAt: day(13, 18), endedAt: day(13, 19), activity: .cycling,
                    distanceMeters: 6_240, newCellsOpened: 34),
            Session(startedAt: day(12, 8), endedAt: day(12, 8), activity: .walking,
                    distanceMeters: 2_180, newCellsOpened: 12),
            Session(startedAt: day(11, 20), endedAt: day(11, 21), activity: .automotive,
                    distanceMeters: 14_800, newCellsOpened: 41),
        ]
    }()

    /// Notable Danang spots along the waterfront — same set as the web prototype.
    static let demoPlaces: [DemoPlace] = [
        .init(id: "han_market", name: "Рынок Хан", category: "Рынок · Chợ Hàn",
              emoji: "🛍️", coord: .init(latitude: 16.0685, longitude: 108.2250)),
        .init(id: "dragon_bridge", name: "Мост Дракона",
              category: "Достопримечательность · Cầu Rồng",
              emoji: "🐉", coord: .init(latitude: 16.0614, longitude: 108.2270)),
        .init(id: "my_khe", name: "Пляж Ми Кхе", category: "Пляж · Bãi biển Mỹ Khê",
              emoji: "🏖️", coord: .init(latitude: 16.0598, longitude: 108.2468)),
        .init(id: "bien_dong", name: "Парк Бьен Донг", category: "Набережная · Biển Đông",
              emoji: "🌊", coord: .init(latitude: 16.0700, longitude: 108.2455)),
    ]

    /// One seeded memory so the journal isn't empty before the first ride.
    static let demoJournal: [Memory] = {
        let date = DateComponents(calendar: .current, year: 2026, month: 7, day: 13,
                                  hour: 18, minute: 40).date ?? Date(timeIntervalSince1970: 1_752_000_000)
        return [
            Memory(placeName: "Рынок Хан", emoji: "🛍️", category: "Рынок · Chợ Hàn",
                   note: "Взял манго и вьетнамский кофе — вернуться за специями.",
                   photo: nil, createdAt: date),
        ]
    }()

    /// Great-circle distance in metres between two coordinates.
    static func distanceMeters(_ a: Coordinate, _ b: Coordinate) -> Double {
        let r = 6_371_000.0
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, sqrt(h)))
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
