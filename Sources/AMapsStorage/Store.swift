import Foundation
import AMapsDomain

/// Persistence boundary. The production implementation is SQLite via GRDB;
/// this protocol keeps the domain and tracking layers unaware of the DB.
public protocol Store: Sendable {
    func save(session: Session) throws
    func loadVisitedCells() throws -> [VisitedCell]
    func insert(cells: [VisitedCell]) throws
    func save(place: Place) throws
    func save(entry: JournalEntry) throws
}

/// In-memory reference implementation for tests and previews.
public final class InMemoryStore: Store, @unchecked Sendable {
    private let lock = NSLock()
    private var sessions: [UUID: Session] = [:]
    private var cells: [CellIndex: VisitedCell] = [:]
    private var places: [UUID: Place] = [:]
    private var entries: [UUID: JournalEntry] = [:]

    public init() {}

    public func save(session: Session) throws {
        lock.withLock { sessions[session.id] = session }
    }
    public func loadVisitedCells() throws -> [VisitedCell] {
        lock.withLock { Array(cells.values) }
    }
    public func insert(cells newCells: [VisitedCell]) throws {
        lock.withLock { for c in newCells where cells[c.index] == nil { cells[c.index] = c } }
    }
    public func save(place: Place) throws {
        lock.withLock { places[place.id] = place }
    }
    public func save(entry: JournalEntry) throws {
        lock.withLock { entries[entry.id] = entry }
    }
}
