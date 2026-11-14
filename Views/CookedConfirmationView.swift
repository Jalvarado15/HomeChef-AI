//
//  CookedConfirmationView.swift
//  HomeChef AI
//
//  Hoja de confirmación de "¡Ya la cociné!": lista los productos del
//  inventario que se van a descontar (ajustables), indica cuáles se eliminan
//  por quedar en 0 y permite decidir si la receta se conserva en el historial.
//

import SwiftUI

struct CookedConfirmationView: View {
    @Bindable var viewModel: RecipeDetailViewModel
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    /// Se puede confirmar si hay algo que descontar o si la receta se va a eliminar.
    private var canConfirm: Bool {
        viewModel.hasAnythingToDeduct || !viewModel.keepRecipe
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if viewModel.deductions.isEmpty {
                        Text("No encontré productos de tu inventario en esta receta.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach($viewModel.deductions) { $deduction in
                            DeductionRow(deduction: $deduction)
                        }
                    }
                } header: {
                    Text("Se descontará de tu inventario")
                } footer: {
                    Text("La receta no indica cantidades exactas: ajusta cuánto usaste. Si es todo lo que tenías, el producto se elimina. Los básicos de tu despensa no se descuentan.")
                }

                Section {
                    Toggle("Conservar receta en mi historial", isOn: $viewModel.keepRecipe)
                } footer: {
                    Text("Si lo desactivas, la receta se elimina al confirmar.")
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
                    .disabled(!canConfirm)
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
