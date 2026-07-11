import Foundation

/// Snapshot of player progress that achievement rules are evaluated against.
public struct ProgressSnapshot: Sendable {
    public var totalCellsOpened: Int
    public var cityCoverage: [String: Double]   // city id -> fraction 0...1
    public var visitedCategories: Set<String>
    public var sessionCount: Int
    public var longestStreakDays: Int

    public init(totalCellsOpened: Int = 0, cityCoverage: [String: Double] = [:],
                visitedCategories: Set<String> = [], sessionCount: Int = 0,
                longestStreakDays: Int = 0) {
        self.totalCellsOpened = totalCellsOpened
        self.cityCoverage = cityCoverage
        self.visitedCategories = visitedCategories
        self.sessionCount = sessionCount
        self.longestStreakDays = longestStreakDays
    }
}

/// Data-driven achievement rule. Definitions ship as JSON in the app bundle so
/// new achievements (seasons, sponsored quests) can be added without a code release.
public struct Achievement: Identifiable, Codable, Sendable {
    public let id: String
    public let title: String
    public let details: String
    public let condition: Condition

    public enum Condition: Codable, Sendable {
        case cellsOpened(Int)
        case cityCoverage(city: String, fraction: Double)
        case visitedCategory(String)
        case sessionCount(Int)
        case streakDays(Int)
    }

    public func isSatisfied(by p: ProgressSnapshot) -> Bool {
        switch condition {
        case .cellsOpened(let n): return p.totalCellsOpened >= n
        case .cityCoverage(let city, let f): return (p.cityCoverage[city] ?? 0) >= f
        case .visitedCategory(let c): return p.visitedCategories.contains(c)
        case .sessionCount(let n): return p.sessionCount >= n
        case .streakDays(let n): return p.longestStreakDays >= n
        }
    }
}

public struct AchievementEngine: Sendable {
    public let catalog: [Achievement]
    public init(catalog: [Achievement]) { self.catalog = catalog }

    /// Returns achievements newly satisfied by `snapshot` that were not already unlocked.
    public func newlyUnlocked(for snapshot: ProgressSnapshot,
                              alreadyUnlocked: Set<String>) -> [Achievement] {
        catalog.filter { !alreadyUnlocked.contains($0.id) && $0.isSatisfied(by: snapshot) }
    }
}
