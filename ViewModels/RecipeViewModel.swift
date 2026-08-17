//
//  RecipeViewModel.swift
//  HomeChef AI
//
//  ViewModel para RecipeListView. Reemplaza el mock anterior por la llamada
//  real a GeminiAIService, manejando estados de carga y error para que la
//  vista pueda reaccionar (spinner, mensaje de error, etc.).
//

import Foundation
import SwiftData

@Observable
final class RecipeViewModel {

    enum State: Equatable {
        case idle
        case loading
        case error(String)
    }

    private(set) var state: State = .idle

    private let aiService: GeminiAIService

    init(aiService: GeminiAIService = GeminiAIService()) {
        self.aiService = aiService
    }

    /// Genera una receta real con Gemini a partir del inventario y la guarda
    /// en el contexto de SwiftData. Actualiza `state` para que la vista
    /// muestre progreso o error según corresponda.
    func generateRecipe(from ingredients: [InventoryItem], context: ModelContext) async {
        state = .loading
        do {
            let recipe = try await aiService.generateRecipe(from: ingredients)
            context.insert(recipe)
            state = .idle
        } catch {
            state = .error(message(for: error))
        }
    }

    func toggleSaved(_ recipe: Recipe) {
        recipe.isSaved.toggle()
    }

    private func message(for error: Error) -> String {
        (error as? GeminiAIServiceError)?.errorDescription
            ?? "Ocurrió un error inesperado al generar la receta."
    }
}
