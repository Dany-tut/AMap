import Foundation
import AMapsDomain

/// Syncs the fog-of-war save state across a user's devices.
///
/// Only visited cells and session metadata are synced — never raw track points,
/// and nothing leaves the user's private iCloud database. Because a visited cell
/// is a single immutable bit keyed by its index, the merge is a set union and
/// therefore conflict-free: two devices that explored while offline simply
/// combine, keeping the earliest first-visit timestamp on collision.
public protocol CloudSync: Sendable {
    /// Push cells opened locally since the last sync.
    func push(_ cells: [VisitedCell]) async throws
    /// Pull cells opened on other devices since `since`.
    func pull(since token: SyncToken?) async throws -> (cells: [VisitedCell], token: SyncToken)
}

public struct SyncToken: Codable, Sendable, Equatable {
    public let raw: Data
    public init(raw: Data) { self.raw = raw }
}

#if canImport(CloudKit)
import CloudKit

/// CloudKit-backed implementation against the user's private database.
public final class CloudKitSync: CloudSync {
    private let database: CKDatabase
    private let zoneID: CKRecordZone.ID

    public init(container: CKContainer = .default(),
                zoneName: String = "Fog") {
        self.database = container.privateCloudDatabase
        self.zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    }

    public func push(_ cells: [VisitedCell]) async throws {
        let records = cells.map { cell -> CKRecord in
            let id = CKRecord.ID(recordName: String(cell.index.rawValue), zoneID: zoneID)
            let r = CKRecord(recordType: "VisitedCell", recordID: id)
            r["firstVisitAt"] = cell.firstVisitAt as NSDate
            r["activity"] = cell.activity.rawValue as NSString
            return r
        }
        // savePolicy .ifServerRecordUnchanged with earliest-wins is handled by the
        // deterministic recordName (one record per cell) — re-pushes are no-ops.
        let op = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        op.savePolicy = .allKeys
        op.isAtomic = false
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            op.modifyRecordsResultBlock = { cont.resume(with: $0) }
            database.add(op)
        }
    }

    public func pull(since token: SyncToken?) async throws
        -> (cells: [VisitedCell], token: SyncToken) {
        let ckToken = token.flatMap {
            try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: CKServerChangeToken.self, from: $0.raw)
        }
        let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        config.previousServerChangeToken = ckToken

        var cells: [VisitedCell] = []
        var newToken = token ?? SyncToken(raw: Data())
        let op = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID], configurationsByRecordZoneID: [zoneID: config])
        op.recordWasChangedBlock = { _, result in
            guard case .success(let record) = result,
                  let raw = UInt64(record.recordID.recordName),
                  let date = record["firstVisitAt"] as? Date else { return }
            let activity = ActivityType(rawValue: record["activity"] as? String ?? "") ?? .unknown
            cells.append(VisitedCell(index: CellIndex(rawValue: raw),
                                     firstVisitAt: date, activity: activity))
        }
        op.recordZoneChangeTokensUpdatedBlock = { _, serverToken, _ in
            if let serverToken,
               let data = try? NSKeyedArchiver.archivedData(
                withRootObject: serverToken, requiringSecureCoding: true) {
                newToken = SyncToken(raw: data)
            }
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            op.recordZoneFetchResultBlock = { _, result in
                switch result {
                case .success(let ok):
                    if let data = try? NSKeyedArchiver.archivedData(
                        withRootObject: ok.serverChangeToken, requiringSecureCoding: true) {
                        newToken = SyncToken(raw: data)
                    }
                    cont.resume()
                case .failure(let error):
                    cont.resume(throwing: error)
                }
            }
            database.add(op)
        }
        return (cells, newToken)
    }
}
#endif
