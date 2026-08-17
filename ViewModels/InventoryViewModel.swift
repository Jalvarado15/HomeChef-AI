//
//  InventoryViewModel.swift
//  HomeChef AI
//
//  ViewModel para InventoryView. Encapsula la lógica de creación de
//  InventoryItem para mantener la vista libre de lógica de negocio.
//

import Foundation
import SwiftData

@Observable
final class InventoryViewModel {

    var name: String = ""
    var quantityText: String = ""
    var category: String = ""

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !category.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(quantityText) != nil
    }

    func addItem(to context: ModelContext) {
        guard let quantity = Double(quantityText) else { return }

        let newItem = InventoryItem(
            name: name.trimmingCharacters(in: .whitespaces),
            quantity: quantity,
            category: category.trimmingCharacters(in: .whitespaces)
        )

        context.insert(newItem)
        resetForm()
    }

    func resetForm() {
        name = ""
        quantityText = ""
        category = ""
    }
}
