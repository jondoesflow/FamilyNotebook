import SwiftUI
import CloudKit
import UIKit

@main
struct FamilyNotebookApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var persistence = Persistence.shared
    @AppStorage("me") private var me: String = ""
    @AppStorage("appearance") private var appearance: Int = 0

    var body: some Scene {
        WindowGroup {
            Group {
                if me.isEmpty {
                    WhoAreYouView()
                } else {
                    HomeView()
                }
            }
            .environment(\.managedObjectContext, persistence.viewContext)
            .environmentObject(persistence)
            .tint(Theme.accent)
            .preferredColorScheme(appearance == 1 ? .light : appearance == 2 ? .dark : nil)
            .onAppear {
                persistence.emptyOldTrash()
                persistence.initializeSchemaIfNeeded()
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

/// Receives the "Katie shared a notebook with you" link.
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            Persistence.shared.acceptShare(metadata)
        }
    }

    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Persistence.shared.acceptShare(cloudKitShareMetadata)
    }
}
