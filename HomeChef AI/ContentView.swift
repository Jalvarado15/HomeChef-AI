//
//  ContentView.swift
//  HomeChef AI
//
//  Vista placeholder temporal. Solo existe para que el proyecto compile
//  con la configuración del ModelContainer. Las vistas reales del MVP
//  (lista de inventario, botón de receta con IA, etc.) se implementarán
//  en la siguiente fase.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            InventoryView()
                .tabItem { Label("Inventario", systemImage: "cart") }
            
            RecipeListView()
                .tabItem { Label("Recetas", systemImage: "fork.knife") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [InventoryItem.self, Recipe.self], inMemory: true)
}
