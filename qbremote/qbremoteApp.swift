//
//  qbremoteApp.swift
//  qbremote
//

import SwiftUI
import SwiftData

@main
struct QBRemoteApp: App {
    @AppStorage("themePreference") private var themePreference: AppTheme = .system
    
    private let transactionListener: Task<Void, Never>

    init() {
        transactionListener = StoreManager.shared.listenForTransactions()
    }

    let container: ModelContainer = {
        let isUITest = ProcessInfo.processInfo.arguments.contains("-isUITest")
        let schema = Schema([ServerProfile.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITest)
        
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            
            if isUITest {
                let context = ModelContext(container)
                let dummyServer = ServerProfile(name: "Home Server", host: "192.168.1.100", port: 8080, username: "admin", isActive: true)
                context.insert(dummyServer)
                try? context.save()
            }
            
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(themePreference.colorScheme)
        }
        .modelContainer(container)
    }
}
