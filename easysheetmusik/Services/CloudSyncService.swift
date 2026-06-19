import CloudKit
import Foundation

final class CloudSyncService {
    enum SyncState: Equatable {
        case unavailable(String)
        case signedOut
        case available
        case syncing
        case failed(String)
    }

    private let container: CKContainer
    private(set) var state: SyncState = .unavailable(T("尚未检查 iCloud 状态", "iCloud status has not been checked"))

    init(container: CKContainer = .default()) {
        self.container = container
    }

    func refreshAccountStatus(completion: @escaping (SyncState) -> Void) {
        container.accountStatus { [weak self] status, error in
            let next: SyncState
            if let error {
                next = .failed(error.localizedDescription)
            } else {
                switch status {
                case .available:
                    next = .available
                case .noAccount, .restricted:
                    next = .signedOut
                case .couldNotDetermine:
                    next = .unavailable(T("无法确定 iCloud 状态", "Could not determine iCloud status"))
                case .temporarilyUnavailable:
                    next = .unavailable(T("iCloud 暂时不可用", "iCloud is temporarily unavailable"))
                @unknown default:
                    next = .unavailable(T("未知 iCloud 状态", "Unknown iCloud status"))
                }
            }
            DispatchQueue.main.async {
                self?.state = next
                completion(next)
            }
        }
    }

    func synchronizeLocalStore(completion: @escaping (SyncState) -> Void) {
        state = .syncing
        // Placeholder for Core Data + NSPersistentCloudKitContainer migration.
        refreshAccountStatus(completion: completion)
    }
}
