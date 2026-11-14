//
//  EditInventoryItemView.swift
//  HomeChef AI
//
//  Formulario en Sheet para editar un InventoryItem existente.
//
//  Usa @Bindable directo sobre el @Model (los cambios se aplican en vivo).
//  La categoría se edita con el mismo Picker estandarizado que el alta.
//  Compatibilidad: si el ítem trae un texto libre antiguo (p. ej. "Verduras"),
//  el Picker muestra la categoría estándar equivalente y, al pulsar "Listo",
//  el valor guardado se normaliza a esa categoría.
//

import SwiftUI
import SwiftData

struct EditInventoryItemView: View {
    @Bindable var item: InventoryItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Detalles del producto") {
                    TextField("Nombre", text: $item.name)

                    TextField("Cantidad", value: $item.quantity, format: .number)
                        .keyboardType(.decimalPad)

                    Picker("Categoría", selection: categoryBinding) {
                        ForEach(IngredientCategory.allCases) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                }
            }
            .navigationTitle("Editar producto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        // Normaliza valores antiguos de texto libre.
                        item.category = IngredientCategory(storedValue: item.category).rawValue
                        dismiss()
                    }
                }
            }
        }
    }

    private var categoryBinding: Binding<IngredientCategory> {
        Binding(
            get: { IngredientCategory(storedValue: item.category) },
            set: { item.category = $0.rawValue }
        )
    }
}

#Preview {
    EditInventoryItemView(
        item: InventoryItem(name: "Tomate", quantity: 3, category: "Verduras")
    )
    .modelContainer(for: [InventoryItem.self, Recipe.self], inMemory: true)
}
