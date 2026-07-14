import UIKit
import CloudKit

/// Routes CloudKit share invitations (links opened from Messages/Mail)
/// into the persistence layer. SwiftUI's lifecycle has no hook for share
/// acceptance, so a scene delegate is injected via the app delegate.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    /// Invitation tapped while the app was already running.
    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        PersistenceController.shared.acceptShare(metadata: cloudKitShareMetadata)
    }

    /// Invitation tapped while the app was closed — it launches with the
    /// share metadata in the connection options.
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            PersistenceController.shared.acceptShare(metadata: metadata)
        }
    }
}
