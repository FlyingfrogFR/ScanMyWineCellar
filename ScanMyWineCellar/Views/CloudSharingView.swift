import SwiftUI
import CloudKit

/// Apple's standard sharing sheet: invite people to a shared cellar,
/// manage participants, copy the invite link, or stop sharing.
struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer

    func makeCoordinator() -> Coordinator {
        Coordinator(share: share)
    }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let share: CKShare

        init(share: CKShare) {
            self.share = share
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            share[CKShare.SystemFieldKey.title] as? String
        }

        func cloudSharingController(
            _ csc: UICloudSharingController,
            failedToSaveShareWithError error: Error
        ) {
            print("Failed to save share: \(error)")
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {}

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {}
    }
}
