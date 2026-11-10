//
//  CoreDataStack.swift
//  KainSpot
//
//  Owns the NSPersistentContainer for the KainSpot model (entity `Spot`).
//  Course week: Week 5 (Core Data persistence).
//

import CoreData
import Foundation

/// Single place that creates and hands out Core Data contexts.
/// `shared` is used by the app; tests can create `CoreDataStack(inMemory: true)` for a throwaway store.
final class CoreDataStack {

    static let shared = CoreDataStack()

    /// Loaded once and reused: creating several containers from separate model copies makes Core Data
    /// warn that multiple entity descriptions claim the generated `Spot` class.
    private static let model: NSManagedObjectModel? = {
        let bundle = Bundle(for: CoreDataStack.self)
        guard let url = bundle.url(forResource: "KainSpot", withExtension: "momd") else { return nil }
        return NSManagedObjectModel(contentsOf: url)
    }()

    let container: NSPersistentContainer

    /// Main-thread context for UI fetches (table view, detail screen).
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// - Parameter inMemory: true writes to /dev/null so nothing persists (unit tests, previews).
    init(inMemory: Bool = false) {
        if let model = CoreDataStack.model {
            container = NSPersistentContainer(name: "KainSpot", managedObjectModel: model)
        } else {
            // Fallback lets Core Data search the main bundle itself.
            container = NSPersistentContainer(name: "KainSpot")
        }

        if inMemory, let description = container.persistentStoreDescriptions.first {
            description.url = URL(fileURLWithPath: "/dev/null")
        }

        // The model gained attributes (kind, avgSpend, hours, amenities...). Lightweight migration lets an
        // existing on-device store open with the new model instead of failing; the new columns get their defaults.
        for description in container.persistentStoreDescriptions {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }

        container.loadPersistentStores { description, error in
            // A broken store should not crash a student demo; log it and keep the app usable.
            if let error = error {
                print("CoreDataStack: failed to load store \(description): \(error)")
            }
        }

        // The model was edited in place (not versioned), so a store written by the OLD app version has no
        // source model to infer a lightweight migration from and fails to open. The Spot table is only a
        // cache of spots.json (user photos are separate files), so the safe fix is: delete that old store,
        // open a fresh one, and clear lastSync so the app re-downloads / re-seeds the spots.
        // loadPersistentStores is synchronous here (shouldAddStoreAsynchronously defaults to false).
        if !inMemory,
           container.persistentStoreCoordinator.persistentStores.isEmpty,
           let storeURL = container.persistentStoreDescriptions.first?.url {
            do {
                try container.persistentStoreCoordinator.destroyPersistentStore(at: storeURL,
                                                                                ofType: NSSQLiteStoreType,
                                                                                options: nil)
                UserPrefs.shared.lastSync = nil
            } catch {
                print("CoreDataStack: could not remove incompatible store: \(error)")
            }
            container.loadPersistentStores { description, error in
                if let error = error {
                    print("CoreDataStack: store still failed after reset \(description): \(error)")
                }
            }
        }

        // Background sync saves flow into the UI context automatically,
        // and on conflicts the newest in-memory values win.
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Private-queue context for heavy work (sync). Always use it inside `context.perform { }`.
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    /// Saves the main context only when something changed; errors are logged instead of crashing.
    func saveContext() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("CoreDataStack: save failed: \(error)")
        }
    }
}
