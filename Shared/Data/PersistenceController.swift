import Foundation
import SwiftData

/// Build-time capability switches, read from Info.plist (set by the xcconfig).
enum Capabilities {
    static var cloudKit: Bool { flag("FoundryCloudKit") }
    static var healthKit: Bool { flag("FoundryHealthKit") }

    private static func flag(_ key: String) -> Bool {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?.uppercased() == "YES"
    }

    static let cloudContainer = "iCloud.com.nicholas6719.foundry"
}

enum PersistenceController {
    enum SyncState: Equatable {
        case iCloud
        case localOnly
        case memoryOnly
    }

    /// Creates the app's container. Falls back from iCloud → local → memory rather than crashing.
    static func makeContainer(inMemory: Bool = false) -> (ModelContainer, SyncState) {
        let schema = Schema(versionedSchema: FoundrySchemaV1.self)
        if inMemory {
            return (memoryContainer(schema), .memoryOnly)
        }
        if Capabilities.cloudKit {
            let config = ModelConfiguration("Foundry", schema: schema, cloudKitDatabase: .private(Capabilities.cloudContainer))
            do {
                let container = try ModelContainer(for: schema, migrationPlan: FoundryMigrationPlan.self, configurations: config)
                return (container, .iCloud)
            } catch {
                Log.data.error("iCloud store failed, falling back to local: \(error.localizedDescription, privacy: .public)")
            }
        }
        let local = ModelConfiguration("Foundry", schema: schema, cloudKitDatabase: .none)
        do {
            let container = try ModelContainer(for: schema, migrationPlan: FoundryMigrationPlan.self, configurations: local)
            return (container, .localOnly)
        } catch {
            Log.data.error("Local store failed, using memory: \(error.localizedDescription, privacy: .public)")
            return (memoryContainer(schema), .memoryOnly)
        }
    }

    private static func memoryContainer(_ schema: Schema) -> ModelContainer {
        let config = ModelConfiguration("FoundryMemory", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // An in-memory store with a valid schema cannot fail; if it does the build is broken.
            preconditionFailure("In-memory SwiftData container failed: \(error)")
        }
    }
}
