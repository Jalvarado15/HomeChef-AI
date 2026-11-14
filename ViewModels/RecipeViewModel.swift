//
//  RecipeViewModel.swift
//  HomeChef AI
//
//  ViewModel para RecipeListView. Antes de llamar a GeminiAIService, valida
//  que haya ingredientes en el inventario; si está vacío, no se hace ninguna
//  petición de red y el estado pasa a .emptyInventory. Las preferencias del
//  perfil culinario se reciben como parámetro y se pasan al servicio.
//

import Foundation
import SwiftData

@Observable
final class RecipeViewModel {

    enum State: Equatable {
        case idle
        case loading
        case emptyInventory
        case error(String)
    }

    private(set) var state: State = .idle

    private let aiService: GeminiAIService

    init(aiService: GeminiAIService = GeminiAIService()) {
        self.aiService = aiService
    }

    /// Genera una receta real con Gemini a partir del inventario y de las
    /// preferencias del usuario, y la guarda en el contexto de SwiftData.
    /// Si `ingredients` está vacío, no se llama a la API.
    func generateRecipe(
        from ingredients: [InventoryItem],
        preferences: CulinaryPreferences,
        context: ModelContext
    ) async {
        guard !ingredients.isEmpty else {
            state = .emptyInventory
            return
        }

        state = .loading
        do {
            let recipe = try await aiService.generateRecipe(from: ingredients, preferences: preferences)
            context.insert(recipe)
            state = .idle
        } catch {
            state = .error(message(for: error))
        }
    }

    func toggleSaved(_ recipe: Recipe) {
        recipe.isSaved.toggle()
    }

    /// Vuelve el estado a .idle, para cerrar alerts sin dejar el estado
    /// "pegado" en .error o .emptyInventory.
    func resetState() {
        state = .idle
    }

    private func message(for error: Error) -> String {
        (error as? GeminiAIServiceError)?.errorDescription
            ?? "Ocurrió un error inesperado al generar la receta."
    }
}
