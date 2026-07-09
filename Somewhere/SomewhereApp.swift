//
//  SomewhereApp.swift
//  Somewhere
//
//  Created by Julian Grønås-Hamre on 10/07/2026.
//

import SwiftUI
import SwiftData

@main
struct SomewhereApp: App {
    let sharedModelContainer: ModelContainer
    private let cornerDrawerController: CornerDrawerController

    init() {
        let schema = Schema([
            StashItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            sharedModelContainer = modelContainer
            cornerDrawerController = CornerDrawerController()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup(id: "archive") {
            ContentView()
                .onAppear {
                    cornerDrawerController.start()
                }
        }
        .modelContainer(sharedModelContainer)

        MenuBarExtra("Somewhere", systemImage: "square.and.arrow.down") {
            QuickAccessView()
        }
        .menuBarExtraStyle(.window)
        .modelContainer(sharedModelContainer)
    }
}
