//
//  SpotSyncService.swift
//  KainSpot
//
//  Downloads the self-published spots.json, decodes it and replaces the Core Data copy.
//  Falls back to the bundled spots.json when offline. Course week: Week 5 (networking + Core Data).
//

import CoreData
import Foundation

/// Errors the sync can report to the UI (which shows a gentle "Offline" banner).
enum SpotSyncError: Error {
    case invalidURL
    case badStatus(Int)
    case noData
}

/// Keeps the local `Spot` table in sync with the remote JSON.
/// URLSession, Core Data stack and bundle are injected so tests can swap them.
final class SpotSyncService {

    /// Convenience instance for controllers; the init with defaults works the same way.
    static let shared = SpotSyncService()

    /// The self-published JSON on GitHub (raw). Optional so callers build it with `guard let`, never a force unwrap.
    static let remoteURL: URL? = URL(string: "https://raw.githubusercontent.com/mtbabaran-collab/kainspot-data/main/spots.json")

    private let session: URLSession
    private let stack: CoreDataStack
    private let bundle: Bundle

    init(session: URLSession = .shared,
         stack: CoreDataStack = .shared,
         bundle: Bundle = Bundle(for: SpotSyncService.self)) {
        self.session = session
        self.stack = stack
        self.bundle = bundle
    }

    /// Shared decode path for both the network response and the bundled fallback file.
    /// snake_case keys in JSON become camelCase properties on `SpotDTO`.
    static func decode(_ data: Data) throws -> [SpotDTO] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([SpotDTO].self, from: data)
    }

    /// Fetches the remote list and replaces all local spots.
    /// Completion always runs on the main queue: `.success(count)` after a save,
    /// or `.failure(error)` after making sure the store at least has the bundled spots.
    func sync(completion: @escaping (Result<Int, Error>) -> Void) {
        guard let url = SpotSyncService.remoteURL else {
            fallBack(after: SpotSyncError.invalidURL, completion: completion)
            return
        }

        // 10 s timeout keeps the pull-to-refresh spinner from hanging on weak campus Wi-Fi;
        // ignoring the local cache makes refresh actually fetch new data.
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                self.fallBack(after: error, completion: completion)
                return
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                self.fallBack(after: SpotSyncError.badStatus(http.statusCode), completion: completion)
                return
            }
            guard let data = data, !data.isEmpty else {
                self.fallBack(after: SpotSyncError.noData, completion: completion)
                return
            }
            do {
                let dtos = try SpotSyncService.decode(data)
                self.replaceAll(with: dtos, completion: completion)
            } catch {
                self.fallBack(after: error, completion: completion)
            }
        }
        task.resume()
    }

    // MARK: - Core Data writes (background context)

    /// Deletes every stored spot and inserts the fresh list in one save.
    /// Fetch-and-delete (not NSBatchDeleteRequest) so the deletions merge into the viewContext automatically.
    /// User photos survive because they are files keyed by spot id ("spot-<id>.jpg"), not Core Data rows.
    private func replaceAll(with dtos: [SpotDTO], completion: @escaping (Result<Int, Error>) -> Void) {
        let context = stack.newBackgroundContext()
        context.perform {
            do {
                let existing = try context.fetch(NSFetchRequest<Spot>(entityName: "Spot"))
                existing.forEach { context.delete($0) }

                let now = Date()
                SpotSyncService.insert(dtos, into: context, syncedAt: now)
                try context.save()

                DispatchQueue.main.async {
                    UserPrefs.shared.lastSync = now
                    completion(.success(dtos.count))
                }
            } catch {
                context.rollback()
                // A failed save still deserves the offline safety net.
                self.fallBack(after: error, completion: completion)
            }
        }
    }

    /// Offline safety net: if the store is empty, seed it from the bundled spots.json so the app still works,
    /// then report the original error so the UI can show "Offline — showing saved spots".
    private func fallBack(after error: Error, completion: @escaping (Result<Int, Error>) -> Void) {
        let context = stack.newBackgroundContext()
        let bundle = self.bundle
        context.perform {
            let count = (try? context.count(for: NSFetchRequest<Spot>(entityName: "Spot"))) ?? 0
            if count == 0 {
                SpotSyncService.seedFromBundle(bundle, into: context)
            }
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }

    /// Reads Resources/spots.json through the same decode path as the network data.
    /// Must be called inside `context.perform`. `syncedAt` stays nil to mark "never synced from the web".
    private static func seedFromBundle(_ bundle: Bundle, into context: NSManagedObjectContext) {
        guard let url = bundle.url(forResource: "spots", withExtension: "json") else {
            print("SpotSyncService: bundled spots.json not found")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let dtos = try decode(data)
            insert(dtos, into: context, syncedAt: nil)
            try context.save()
        } catch {
            context.rollback()
            print("SpotSyncService: could not seed from bundle: \(error)")
        }
    }

    /// Copies each DTO into a new managed `Spot`. Must be called inside `context.perform`.
    private static func insert(_ dtos: [SpotDTO], into context: NSManagedObjectContext, syncedAt: Date?) {
        for dto in dtos {
            let spot = Spot(context: context)
            spot.id = dto.id
            spot.name = dto.name
            spot.category = dto.category
            spot.priceLevel = dto.priceLevel
            spot.rating = dto.rating
            spot.latitude = dto.latitude
            spot.longitude = dto.longitude
            spot.isTrending = dto.isTrending
            spot.address = dto.address
            spot.blurb = dto.blurb
            spot.syncedAt = syncedAt
        }
    }
}
