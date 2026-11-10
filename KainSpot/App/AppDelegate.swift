//
//  AppDelegate.swift
//  KainSpot
//
//  App entry point: owns process-level lifecycle (launch, scene configuration, termination).
//  Course weeks: Week 1 (iOS app lifecycle / project structure) and Week 7 (persisting Core Data on exit).
//

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    /// Launch hook. The UI is built by Main.storyboard through the scene manifest in Info.plist,
    /// so nothing is created here. The "-uiDemo" launch argument (used by the UI demo test)
    /// intentionally needs no special handling: the demo walks the real app with real behavior.
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Touch the shared stack early so the persistent store is loaded before the first screen fetches.
        _ = CoreDataStack.shared.viewContext
        return true
    }

    // MARK: UISceneSession Lifecycle

    /// Returns the single "Default Configuration" declared in Info.plist (SceneDelegate + Main storyboard).
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    /// Last-chance save: if the system terminates the app, unsaved Core Data edits are written to disk.
    func applicationWillTerminate(_ application: UIApplication) {
        CoreDataStack.shared.saveContext()
    }
}
