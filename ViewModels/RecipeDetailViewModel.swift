//
//  RecipeDetailViewModel.swift
//  HomeChef AI
//
//  Lógica de "¡Ya la cociné!": calcula qué productos del inventario descontar
//  (excluyendo los básicos de la despensa), aplica el descuento tras la
//  confirmación y, si el usuario no quiere conservar la receta, la elimina.
//
//  La hoja de confirmación muestra copias (nombre y cantidad), no referencias
//  a los @Model, para no leer ítems ya eliminados mientras se cierra.
//

import Foundation
import SwiftData

@Observable
final class RecipeDetailViewModel {

    /// Margen para comparar cantidades Double al decidir si un ítem llega a 0.
    static let epsilon = 0.0001

    struct Deduction: Identifiable {
        /// id del InventoryItem al que corresponde.
        let id: UUID
        let name: String
        let currentQuantity: Double
        var amount: Double

        var remainingQuantity: Double { max(currentQuantity - amount, 0) }

        /// `true` si lo que se descuenta agota el producto.
        var removesItem: Bool {
            amount > 0 && currentQuantity - amount <= RecipeDetailViewModel.epsilon
        }
    }

    var deductions: [Deduction] = []
    var isShowingConfirmation = false

    /// Toggle "Conservar receta en mi historial".
    var keepRecipe = false

    /// Se activa al confirmar con `keepRecipe == false`; la vista elimina la
    /// receta cuando la hoja termina de cerrarse.
    private(set) var discardRecipeOnDismiss = false

    var hasAnythingToDeduct: Bool {
        deductions.contains { $0.amount > 0 }
    }

    /// Calcula los productos a descontar y abre la hoja de confirmación.
    /// - Los básicos de la despensa (`staples`) nunca se sugieren.
    /// - Por defecto se propone descontar 1 unidad de cada producto (la receta
    ///   no indica cantidades exactas); el usuario puede ajustarlo.
    /// - `keepRecipe` arranca en `true` solo si la receta ya estaba guardada.
    func prepareDeductions(for recipe: Recipe, inventory: [InventoryItem], staples: [String]) {
        let recipeText = recipe.title + "\n" + recipe.content

        deductions = inventory
            .filter {
                $0.quantity > 0 &&
                IngredientMatcher.matches(itemName: $0.name, in: recipeText, excludingStaples: staples)
            }
            .map {
                Deduction(
                    id: $0.id,
                    name: $0.name,
                    currentQuantity: $0.quantity,
                    amount: min(1, $0.quantity)
                )
            }

        keepRecipe = recipe.isSaved
        discardRecipeOnDismiss = false
        isShowingConfirmation = true
    }

    /// Aplica los descuentos (resta o elimina el ítem si llega a 0), guarda y
    /// cierra la hoja. Si `keepRecipe` es `false`, marca la receta para
    /// eliminarla cuando la hoja termine de cerrarse.
    func confirmDeductions(inventory: [InventoryItem], context: ModelContext) {
        let itemsByID = Dictionary(
            inventory.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for deduction in deductions where deduction.amount > 0 {
            guard let item = itemsByID[deduction.id] else { continue }

            let remaining = item.quantity - deduction.amount
            if remaining <= Self.epsilon {
                context.delete(item)
            } else {
                item.quantity = remaining
            }
        }

        try? context.save()
        discardRecipeOnDismiss = !keepRecipe
        isShowingConfirmation = false
    }

    /// Elimina la receta del contexto y guarda.
    func discard(_ recipe: Recipe, context: ModelContext) {
        context.delete(recipe)
        try? context.save()
    }

    /// Limpia el estado una vez cerrada la hoja (por confirmar o cancelar).
    func clearDeductions() {
        deductions = []
        discardRecipeOnDismiss = false
    }
}
