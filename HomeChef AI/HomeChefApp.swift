//
//  HomeChefApp.swift
//  HomeChef AI
//
//  Punto de entrada de la app. Configura el ModelContainer de SwiftData
//  e inyecta el contexto de la base de datos a toda la jerarquía de vistas.
//

import SwiftUI
import SwiftData

@main
struct HomeChefApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            InventoryItem.self,
            Recipe.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("No se pudo crear el ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
