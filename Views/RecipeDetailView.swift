//
//  RecipeDetailView.swift
//  HomeChef AI
//
//  Muestra el contenido completo de una receta como una tarjeta de cocina:
//  título en serif, párrafos generales como texto simple, y líneas
//  numeradas del mock ("1. ...", "2. ...") renderizadas como pasos con
//  badge circular, dentro de una sección destacada.
//

import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    @Bindable var recipe: Recipe

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                ContentCard(blocks: parsedContent)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Detalle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    recipe.isSaved.toggle()
                } label: {
                    Image(systemName: recipe.isSaved ? "star.fill" : "star")
                        .foregroundStyle(recipe.isSaved ? .yellow : .primary)
                }
            }
        }
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
                Ingredientes utilizados: Tomate, Cebolla, Ajo

                Instrucciones (simuladas):
                1. Prepara todos los ingredientes disponibles.
                2. Combínalos según la técnica adecuada para cada uno.
                3. Cocina a fuego medio hasta obtener el resultado deseado.
                4. Sirve y disfruta.

                (Este contenido es un mock temporal.)
                """,
                isSaved: false
            )
        )
    }
    .modelContainer(for: [InventoryItem.self, Recipe.self], inMemory: true)
}
