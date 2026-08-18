//
//  EditInventoryItemView.swift
//  HomeChef AI
//
//  Formulario en Sheet para editar un InventoryItem existente.
//
//  Usa @Bindable directo sobre el @Model: es el patrón oficial recomendado
//  por Apple para editar SwiftData (los TextField mutan el objeto en vivo,
//  por lo que "por qué" no hay un botón "Cancelar" que revierta cambios:
//  agregar un borrador/copia local solo para permitir deshacer sería
//  sobreingeniería para este MVP — punto 19 del documento maestro).
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

                    TextField("Categoría", text: $item.category)
                }
            }
            .navigationTitle("Editar producto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    EditInventoryItemView(
        item: InventoryItem(name: "Tomate", quantity: 3, category: "Verduras")
    )
    .modelContainer(for: [InventoryItem.self, Recipe.self], inMemory: true)
}
