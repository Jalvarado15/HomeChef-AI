//
//  RecipeListView.swift
//  HomeChef AI
//
//  Muestra las recetas generadas (@Query), dispara la generación real con
//  GeminiAIService, y ahora permite eliminar una receta guardada mediante
//  swipe-to-delete (modelContext.delete).
//

import SwiftUI
import SwiftData

struct RecipeListView: View {
    @Query(sort: \Recipe.generatedDate, order: .reverse)
    private var recipes: [Recipe]

    @Query private var inventoryItems: [InventoryItem]

    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = RecipeViewModel()

    private var isLoading: Bool {
        viewModel.state == .loading
    }

    var body: some View {
        NavigationStack {
            List {
                if recipes.isEmpty {
                    ContentUnavailableView(
                        "Sin recetas todavía",
                        systemImage: "fork.knife",
                        description: Text("Genera una receta con los ingredientes de tu inventario")
                    )
                } else {
                    ForEach(recipes) { recipe in
                        NavigationLink(value: recipe) {
                            RecipeRow(recipe: recipe)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(recipe)
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Recetas")
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await viewModel.generateRecipe(from: inventoryItems, context: modelContext)
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Label("Generar receta", systemImage: "sparkles")
                        }
                    }
                    .disabled(inventoryItems.isEmpty || isLoading)
                }
            }
            .alert(
                "No se pudo generar la receta",
                isPresented: errorAlertBinding,
                actions: {
                    Button("OK", role: .cancel) { }
                },
                message: {
                    Text(errorMessage ?? "")
                }
            )
        }
    }

    private func delete(_ recipe: Recipe) {
        modelContext.delete(recipe)
    }

    private var errorMessage: String? {
        if case .error(let message) = viewModel.state {
            return message
        }
        return nil
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { _ in }
        )
    }
}

private struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(.headline)
                Text(recipe.generatedDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if recipe.isSaved {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
            }
        }
    }
}

#Preview {
    RecipeListView()
        .modelContainer(for: [InventoryItem.self, Recipe.self], inMemory: true)
}
