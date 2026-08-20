//
//  RecipeListView.swift
//  HomeChef AI
//
//  Muestra las recetas generadas (@Query), dispara la generación real con
//  GeminiAIService, permite eliminar recetas guardadas, maneja el caso de
//  inventario vacío, y ahora permite reintentar la generación directamente
//  desde el alert de error (Fase 5: resiliencia ante fallos de red/API).
//

import SwiftUI
import SwiftData

struct RecipeListView: View {
    @Query(sort: \Recipe.generatedDate, order: .reverse)
    private var recipes: [Recipe]

    @Query private var inventoryItems: [InventoryItem]

    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = RecipeViewModel()
    @State private var isShowingAddItemSheet = false

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
                        triggerGeneration()
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Label("Generar receta", systemImage: "sparkles")
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .sheet(isPresented: $isShowingAddItemSheet) {
                AddInventoryItemView()
            }
            .alert(
                "Necesitas ingredientes primero",
                isPresented: emptyInventoryAlertBinding,
                actions: {
                    Button("Agregar ingredientes") {
                        viewModel.resetState()
                        isShowingAddItemSheet = true
                    }
                    Button("Cancelar", role: .cancel) {
                        viewModel.resetState()
                    }
                },
                message: {
                    Text("Tu inventario está vacío. Agrega al menos un producto para poder generar una receta.")
                }
            )
            .alert(
                "No se pudo generar la receta",
                isPresented: errorAlertBinding,
                actions: {
                    Button("Reintentar") {
                        viewModel.resetState()
                        triggerGeneration()
                    }
                    Button("Cancelar", role: .cancel) {
                        viewModel.resetState()
                    }
                },
                message: {
                    Text(errorMessage ?? "")
                }
            )
        }
    }

    /// Punto único para disparar la generación, usado tanto por el botón
    /// de la toolbar como por "Reintentar" en el alert de error.
    private func triggerGeneration() {
        Task {
            await viewModel.generateRecipe(from: inventoryItems, context: modelContext)
        }
    }

    private func delete(_ recipe: Recipe) {
        modelContext.delete(recipe)
    }

    // MARK: - Alert bindings

    private var errorMessage: String? {
        if case .error(let message) = viewModel.state {
            return message
        }
        return nil
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented { viewModel.resetState() }
            }
        )
    }

    private var emptyInventoryAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state == .emptyInventory },
            set: { isPresented in
                if !isPresented { viewModel.resetState() }
            }
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
