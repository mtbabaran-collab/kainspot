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

        container.loadPersistentStores { description, error in
            // A broken store should not crash a student demo; log it and keep the app usable.
            if let error = error {
                print("CoreDataStack: failed to load store \(description): \(error)")
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
