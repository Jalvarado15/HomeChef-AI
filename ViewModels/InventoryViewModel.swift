//
//  InventoryViewModel.swift
//  HomeChef AI
//
//  ViewModel del formulario de alta de InventoryItem. Sugiere la categoría
//  a partir del nombre mientras el usuario no la haya elegido a mano.
//

import Foundation
import SwiftData

@Observable
final class InventoryViewModel {

    var name: String = ""
    var quantityText: String = ""
    private(set) var category: IngredientCategory = .otros

    /// Una vez que el usuario elige una categoría manualmente, dejamos de
    /// sobrescribirla con sugerencias automáticas.
    private var isCategoryManuallySelected = false

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(quantityText) != nil
    }

    /// Llamar cuando cambia `name`: aplica la sugerencia local si procede.
    func nameDidChange() {
        guard !isCategoryManuallySelected else { return }
        category = IngredientCategory.suggestCategory(for: name)
    }

    /// Llamar cuando el usuario cambia el Picker a mano.
    func selectCategory(_ newCategory: IngredientCategory) {
        isCategoryManuallySelected = true
        category = newCategory
    }

    func addItem(to context: ModelContext) {
        guard let quantity = Double(quantityText) else { return }

        let newItem = InventoryItem(
            name: name.trimmingCharacters(in: .whitespaces),
            quantity: quantity,
            category: category.rawValue
        )

        context.insert(newItem)
        resetForm()
    }

    func resetForm() {
        name = ""
        quantityText = ""
        category = .otros
        isCategoryManuallySelected = false
    }
}
