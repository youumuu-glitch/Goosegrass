import SwiftUI
import SwiftData

@main
struct GoosegrassApp: App {
    private let persistenceController: PersistenceController

    init() {
        do {
            persistenceController = try PersistenceController()
        } catch {
            fatalError("Unable to initialize the local data store: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(persistenceController.container)
    }
}
