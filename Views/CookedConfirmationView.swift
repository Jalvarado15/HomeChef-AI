//
//  CookedConfirmationView.swift
//  HomeChef AI
//
//  Hoja de confirmación de "¡Ya la cociné!": lista los productos del
//  inventario que se van a descontar, deja ajustar cuánto se usó de cada
//  uno e indica cuáles se eliminarán por quedar en 0.
//

import SwiftUI

struct CookedConfirmationView: View {
    @Bindable var viewModel: RecipeDetailViewModel
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($viewModel.deductions) { $deduction in
                        DeductionRow(deduction: $deduction)
                    }
                } header: {
                    Text("Se descontará de tu inventario")
                } footer: {
                    Text("La receta no indica cantidades exactas: ajusta cuánto usaste. Si es todo lo que tenías, el producto se elimina.")
                }
            }
            .navigationTitle("¡Buen provecho!")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar") {
                        onConfirm()
                    }
                    .disabled(!viewModel.hasAnythingToDeduct)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct DeductionRow: View {
    @Binding var deduction: RecipeDetailViewModel.Deduction

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(deduction.name)
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Text("Tienes \(format(deduction.currentQuantity))")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Stepper(
                value: $deduction.amount,
                in: 0...max(deduction.currentQuantity, 0),
                step: 1
            ) {
                Text("Descontar: \(format(deduction.amount))")
                    .font(.system(.subheadline, design: .rounded))
            }

            statusText
                .font(.caption)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusText: some View {
        if deduction.removesItem {
            Text("Se eliminará del inventario")
                .foregroundStyle(.red)
        } else if deduction.amount > 0 {
            Text("Quedarán \(format(deduction.remainingQuantity))")
                .foregroundStyle(.secondary)
        } else {
            Text("No se descontará")
                .foregroundStyle(.secondary)
        }
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}
