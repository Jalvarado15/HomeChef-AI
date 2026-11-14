//
//  AddInventoryItemView.swift
//  HomeChef AI
//
//  Formulario en Sheet para agregar un InventoryItem. La categoría se elige
//  con un Picker estandarizado y se sugiere automáticamente al escribir el
//  nombre, hasta que el usuario la cambie manualmente.
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
                Section {
                    TextField("Nombre", text: $viewModel.name)

                    TextField("Cantidad", text: $viewModel.quantityText)
                        .keyboardType(.decimalPad)

                    Picker("Categoría", selection: categoryBinding) {
                        ForEach(IngredientCategory.allCases) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                } header: {
                    Text("Detalles del producto")
                } footer: {
                    Text("La categoría se sugiere según el nombre; puedes cambiarla cuando quieras.")
                }
            }
            .onChange(of: viewModel.name) {
                viewModel.nameDidChange()
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

    /// Binding propio para distinguir un cambio hecho por el usuario
    /// (marca la categoría como manual) de una sugerencia automática.
    private var categoryBinding: Binding<IngredientCategory> {
        Binding(
            get: { viewModel.category },
            set: { viewModel.selectCategory($0) }
        )
    }
}

#Preview {
    AddInventoryItemView()
        .modelContainer(for: [InventoryItem.self, Recipe.self], inMemory: true)
}
