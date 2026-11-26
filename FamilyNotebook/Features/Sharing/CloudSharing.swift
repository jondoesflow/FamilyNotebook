import SwiftUI
import CloudKit
import UIKit

/// Presents Apple's standard iCloud sharing sheet (send via Messages, Mail, copy link…).
/// Katie taps the link, the notebook appears on her shelf, and you both edit it.
@MainActor
enum CloudSharing {
    static func present(for notebook: Notebook, persistence: Persistence) async throws {
        let share = try await persistence.makeShare(for: notebook)
        let controller = UICloudSharingController(share: share, container: persistence.ckContainer)
        let delegate = SharingDelegate(notebook: notebook, persistence: persistence)
        controller.delegate = delegate
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.modalPresentationStyle = .formSheet
        objc_setAssociatedObject(controller, &SharingDelegate.key, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        guard let top = topViewController() else { return }
        if let pop = controller.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: 80, width: 1, height: 1)
        }
        top.present(controller, animated: true)
    }

    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        var top = scene?.keyWindow?.rootViewController ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

@MainActor
final class SharingDelegate: NSObject, UICloudSharingControllerDelegate {
    nonisolated(unsafe) static var key: UInt8 = 0
    let notebook: Notebook
    let persistence: Persistence

    init(notebook: Notebook, persistence: Persistence) {
        self.notebook = notebook
        self.persistence = persistence
    }

    func itemTitle(for csc: UICloudSharingController) -> String? { notebook.displayTitle }

    func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
        let renderer = ImageRenderer(content: NotebookCover(cover: notebook.cover, photo: notebook.coverPhoto).frame(width: 120, height: 166))
        renderer.scale = 2
        return renderer.uiImage?.pngData()
    }

    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        print("Sharing failed: \(error)")
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        if let share = csc.share { persistence.persistUpdatedShare(share) }
    }

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        // If I was a participant and left, remove my local copy.
        if persistence.isParticipantCopy(notebook), let share = csc.share {
            persistence.purgeShare(share)
        } else if let share = csc.share {
            persistence.persistUpdatedShare(share)
        }
    }
}
