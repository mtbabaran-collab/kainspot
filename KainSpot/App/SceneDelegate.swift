//
//  SceneDelegate.swift
//  KainSpot
//
//  Window/scene lifecycle. The window and root navigation controller come from Main.storyboard
//  (UISceneStoryboardFile), so this class only reacts to foreground/background changes.
//  Course weeks: Week 1 (scene lifecycle) and Week 7 (saving Core Data when the app leaves the screen).
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    /// Set automatically by UIKit when the storyboard-backed scene connects.
    var window: UIWindow?

    /// The storyboard already installs the initial UINavigationController; we only make sure
    /// the scene really is a window scene and apply the brand tint to the whole window.
    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard scene is UIWindowScene else { return }
        // Brand orange #FF6B35 (same value as Theme.primary) so system controls match the app.
        window?.tintColor = UIColor(red: 1.0, green: 107.0 / 255.0, blue: 53.0 / 255.0, alpha: 1.0)
    }

    /// iOS may kill a backgrounded app without calling applicationWillTerminate,
    /// so this is the reliable moment to persist any pending Core Data changes.
    func sceneDidEnterBackground(_ scene: UIScene) {
        CoreDataStack.shared.saveContext()
    }
}
