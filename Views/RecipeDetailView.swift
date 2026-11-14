//
//  RecipeDetailView.swift
//  HomeChef AI
//
//  Tarjeta de cocina con el contenido de la receta y el botón fijo
//  "¡Ya la cociné!". Si el usuario decide no conservar la receta, se elimina
//  una vez que la hoja de confirmación termina de cerrarse y esta pantalla
//  se cierra sola.
//

import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    @Bindable var recipe: Recipe

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \InventoryItem.name) private var inventoryItems: [InventoryItem]
    @Query private var profiles: [UserProfile]

    @State private var viewModel = RecipeDetailViewModel()

    /// Se activa justo antes de eliminar la receta, para que la vista deje de
    /// leerla mientras se cierra.
    @State private var isDiscarded = false

    private let accent = Color(red: 0.30, green: 0.45, blue: 0.32) // basil

    var body: some View {
        Group {
            if isDiscarded {
                Color(.systemGroupedBackground).ignoresSafeArea()
            } else {
                recipeContent
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !isDiscarded {
                cookedButton
            }
        }
        .navigationTitle("Detalle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !isDiscarded {
                    Button {
                        recipe.isSaved.toggle()
                    } label: {
                        Image(systemName: recipe.isSaved ? "star.fill" : "star")
                            .foregroundStyle(recipe.isSaved ? .yellow : .primary)
                    }
                }
            }
        }
        .sheet(
            isPresented: $viewModel.isShowingConfirmation,
            onDismiss: handleSheetDismiss
        ) {
            CookedConfirmationView(viewModel: viewModel) {
                viewModel.confirmDeductions(inventory: inventoryItems, context: modelContext)
            }
        }
    }

    // MARK: - Contenido

    private var recipeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                ContentCard(blocks: parsedContent)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(recipe.title)
                .font(.system(.largeTitle, design: .serif))
                .fontWeight(.bold)

            Text("Generada el \(recipe.generatedDate.formatted(date: .abbreviated, time: .shortened))")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    /// Botón principal fijo en la parte inferior de la pantalla.
    private var cookedButton: some View {
        Button {
            viewModel.prepareDeductions(
                for: recipe,
                inventory: inventoryItems,
                staples: profiles.flatMap(\.pantryStaples)
            )
        } label: {
            Label("¡Ya la cociné!", systemImage: "checkmark.circle.fill")
                .font(.system(.headline, design: .rounded))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(accent)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Cierre de la hoja

    /// Cuando la hoja ya se cerró: si el usuario eligió no conservar la receta,
    /// se elimina, se guarda y se cierra esta pantalla.
    private func handleSheetDismiss() {
        let shouldDiscard = viewModel.discardRecipeOnDismiss
        viewModel.clearDeductions()

        guard shouldDiscard else { return }

        isDiscarded = true
        viewModel.discard(recipe, context: modelContext)
        dismiss()
    }

    // MARK: - Parseo del contenido

    /// Convierte recipe.content en bloques: párrafos normales o pasos
    /// numerados (líneas que empiezan con "1. ", "2. ", etc.).
    private var parsedContent: [ContentBlock] {
        recipe.content
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { line in
                if let range = line.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                    let numberText = line[..<range.upperBound]
                        .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
                    let stepText = String(line[range.upperBound...])
                    if let number = Int(numberText) {
                        return .step(number, stepText)
                    }
                }
                return .paragraph(line)
            }
    }
}

private enum ContentBlock: Identifiable {
    case paragraph(String)
    case step(Int, String)

    var id: String {
        switch self {
        case .paragraph(let text): return "p-\(text)"
        case .step(let number, let text): return "s-\(number)-\(text)"
        }
    }
}

/// Sección destacada que agrupa todo el contenido de la receta (ingredientes,
/// notas y pasos) sobre un fondo tenue con esquinas redondeadas.
private struct ContentCard: View {
    let blocks: [ContentBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(blocks) { block in
                switch block {
                case .paragraph(let text):
                    Text(text)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.primary)

                case .step(let number, let text):
                    StepRow(number: number, text: text)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
    }
}

/// Fila de un paso numerado, con badge circular de color basil.
private struct StepRow: View {
    let number: Int
    let text: String

    private let accent = Color(red: 0.30, green: 0.45, blue: 0.32) // basil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.16))
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.system(.footnote, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(accent)
            }

            Text(text)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    NavigationStack {
        RecipeDetailView(
            recipe: Recipe(
                title: "Receta sugerida con Tomate",
                content: """
                1. Prepara todos los ingredientes disponibles.
                2. Combínalos según la técnica adecuada para cada uno.
                3. Cocina a fuego medio hasta obtener el resultado deseado.
                4. Sirve y disfruta.
                """,
                isSaved: false
            )
        )
    }
    .modelContainer(for: [InventoryItem.self, Recipe.self, UserProfile.self], inMemory: true)
}
