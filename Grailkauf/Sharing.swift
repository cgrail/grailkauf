import CloudKit
import CoreData
import SwiftUI

extension Store {
    /// The CloudKit share of the household's list, created on first use.
    func share() async throws -> (CKShare, CKContainer) {
        guard let list = activeList() else { throw CocoaError(.persistentStoreOpen) }
        if let existing = try container.fetchShares(matching: [list.objectID])[list.objectID] {
            return (existing, CKContainer(identifier: Self.containerID))
        }
        let (_, share, cloud) = try await container.share([list], to: nil)
        share[CKShare.SystemFieldKey.title] = "Grailkauf"
        if let privateStore { try await container.persistUpdatedShare(share, in: privateStore) }
        return (share, cloud)
    }

    func accept(_ invitation: CKShare.Metadata) async throws {
        guard let sharedStore else { throw CocoaError(.persistentStoreOpen) }
        try await container.acceptShareInvitations(from: [invitation], into: sharedStore)
    }
}

/// The system sheet for inviting people and managing who has access.
struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.modalPresentationStyle = .formSheet
        return controller
    }

    func updateUIViewController(_ controller: UICloudSharingController, context: Context) {}
}
