import Foundation
import AMapsDomain

/// Abstracts the grid used for fog-of-war. Production backs this with H3
/// (res 10-11); tests use a simple deterministic grid so the engine logic
/// can be exercised without the C library.
public protocol GridProjection: Sendable {
    func cell(for coordinate: Coordinate) -> CellIndex
}

/// Tracks which grid cells have ever been explored. A visited cell is a single
/// bit of state; the set forms a natural CRDT (union merges are conflict-free),
/// which is what makes CloudKit sync between devices trivial.
public final class FogEngine {
    private let grid: GridProjection
    private var visited: [CellIndex: VisitedCell]

    public init(grid: GridProjection, existing: [VisitedCell] = []) {
        self.grid = grid
        self.visited = Dictionary(uniqueKeysWithValues: existing.map { ($0.index, $0) })
    }

    public var visitedCount: Int { visited.count }
    public func allVisited() -> [VisitedCell] { Array(visited.values) }
    public func isOpen(_ index: CellIndex) -> Bool { visited[index] != nil }

    /// Records a fix. Returns the cell if it was newly opened (fires achievements
    /// and the map reveal animation), or nil if that cell was already explored.
    @discardableResult
    public func observe(_ coordinate: Coordinate, at time: Date,
                        activity: ActivityType) -> VisitedCell? {
        let index = grid.cell(for: coordinate)
        if visited[index] != nil { return nil }
        let cell = VisitedCell(index: index, firstVisitAt: time, activity: activity)
        visited[index] = cell
        return cell
    }

    /// Conflict-free merge of visited cells synced from another device.
    /// Keeps the earliest first-visit timestamp on collision.
    public func merge(_ incoming: [VisitedCell]) {
        for cell in incoming {
            if let existing = visited[cell.index] {
                if cell.firstVisitAt < existing.firstVisitAt { visited[cell.index] = cell }
            } else {
                visited[cell.index] = cell
            }
        }
    }

    /// Fraction (0...1) of a city's cells that have been opened.
    public func coverage(ofCityCells cityCells: Set<CellIndex>) -> Double {
        guard !cityCells.isEmpty else { return 0 }
        let opened = cityCells.reduce(into: 0) { acc, c in acc += visited[c] != nil ? 1 : 0 }
        return Double(opened) / Double(cityCells.count)
    }
}
