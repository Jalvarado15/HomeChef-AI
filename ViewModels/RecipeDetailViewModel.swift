//
//  RecipeDetailViewModel.swift
//  HomeChef AI
//
//  Lógica del botón "¡Ya la cociné!": busca qué productos del inventario
//  aparecen en la receta, propone cuánto descontar de cada uno y, tras la
//  confirmación del usuario, aplica los cambios en SwiftData.
//
//  Los datos que muestra la hoja de confirmación son copias (nombre y
//  cantidad al momento de calcular), no referencias a los @Model, para que la
//  interfaz nunca lea un ítem que ya fue eliminado mientras se cierra.
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
    var isShowingNoMatchAlert = false

    var hasAnythingToDeduct: Bool {
        deductions.contains { $0.amount > 0 }
    }

    /// Calcula los productos a descontar. Si no hay coincidencias avisa con
    /// una alerta; si las hay, abre la hoja de confirmación. Por defecto se
    /// propone descontar 1 unidad de cada producto (la receta no indica
    /// cantidades exactas), que el usuario puede ajustar.
    func prepareDeductions(for recipe: Recipe, inventory: [InventoryItem]) {
        let recipeText = recipe.title + "\n" + recipe.content

        deductions = inventory
            .filter { $0.quantity > 0 && IngredientMatcher.matches(itemName: $0.name, in: recipeText) }
            .map {
                Deduction(
                    id: $0.id,
                    name: $0.name,
                    currentQuantity: $0.quantity,
                    amount: min(1, $0.quantity)
                )
            }

        if deductions.isEmpty {
            isShowingNoMatchAlert = true
        } else {
            isShowingConfirmation = true
        }
    }

    /// Aplica los descuentos: resta la cantidad y, si el ítem llega a 0,
    /// lo elimina. Guarda los cambios en el contexto.
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
        isShowingConfirmation = false
    }

    /// Limpia el estado una vez cerrada la hoja (por confirmar o cancelar).
    func clearDeductions() {
        deductions = []
    }
}
