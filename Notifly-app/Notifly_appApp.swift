import SwiftUI
import SwiftData

@main
struct Notifly_appApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SessionNote.self,
            NoteTemplate.self,
        ])
        let storeURL = URL.applicationSupportDirectory.appending(path: "Notifly.store")
        let modelConfiguration = ModelConfiguration(schema: schema, url: storeURL, allowsSave: true)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Store is incompatible with the new schema — delete and retry
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(filePath: storeURL.path() + suffix))
            }
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(sharedModelContainer)
    }
}
