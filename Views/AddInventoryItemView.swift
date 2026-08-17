//
//  AddInventoryItemView.swift
//  HomeChef AI
//
//  Formulario en Sheet para agregar un InventoryItem. Usa InventoryViewModel
//  para la validación y creación del item.
//

import SwiftUI
import SwiftData

struct AddInventoryItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = InventoryViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Detalles del producto") {
                    TextField("Nombre", text: $viewModel.name)

                    TextField("Cantidad", text: $viewModel.quantityText)
                        .keyboardType(.decimalPad)

                    TextField("Categoría", text: $viewModel.category)
                }
            }
            .navigationTitle("Nuevo producto")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        viewModel.addItem(to: modelContext)
                        dismiss()
                    }
                    .disabled(!viewModel.isFormValid)
                }
            }
        }
    }
}

#Preview {
    AddInventoryItemView()
        .modelContainer(for: [InventoryItem.self, Recipe.self], inMemory: true)
}
