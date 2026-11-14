//
//  IngredientMatcher.swift
//  HomeChef AI
//
//  Funciones puras de comparación de ingredientes. Usan la misma
//  normalización que el clasificador de categorías: ignoran mayúsculas,
//  tildes y plurales simples.
//
//  - matches(itemName:in:excludingStaples:): ¿el producto aparece en el texto
//    de la receta? Nunca coincide si es un básico de la despensa.
//  - isPantryStaple(itemName:staples:): ¿el producto es un básico? Un básico
//    coincide cuando TODAS sus palabras significativas aparecen en el nombre
//    del producto ("sal" → "Sal gruesa"; "aceite de oliva" no coincide con
//    "Aceite de coco").
//

import Foundation

enum IngredientMatcher {

    /// Palabras que no identifican un ingrediente por sí solas.
    private static let stopwords: Set<String> = [
        "de", "del", "la", "el", "los", "las", "con", "en", "y", "al",
        "para", "sin", "un", "una", "por"
    ]

    /// `true` si alguna palabra significativa de `itemName` aparece en
    /// `recipeText`. Los básicos de la despensa quedan siempre excluidos.
    static func matches(
        itemName: String,
        in recipeText: String,
        excludingStaples staples: [String] = []
    ) -> Bool {
        guard !isPantryStaple(itemName: itemName, staples: staples) else { return false }

        let recipeForms = Set(tokens(of: recipeText).flatMap(forms(of:)))

        return significantTokens(of: itemName).contains { token in
            forms(of: token).contains { recipeForms.contains($0) }
        }
    }

    /// `true` si `itemName` corresponde a alguno de los básicos de la despensa.
    static func isPantryStaple(itemName: String, staples: [String]) -> Bool {
        guard !staples.isEmpty else { return false }

        let itemForms = Set(significantTokens(of: itemName).flatMap(forms(of:)))

        return staples.contains { staple in
            let required = significantTokens(of: staple)
            guard !required.isEmpty else { return false }
            return required.allSatisfy { token in
                forms(of: token).contains { itemForms.contains($0) }
            }
        }
    }

    // MARK: - Normalización

    private static func tokens(of text: String) -> [String] {
        CulinaryPreferences.fold(text)
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
    }

    private static func significantTokens(of text: String) -> [String] {
        tokens(of: text).filter { $0.count >= 3 && !stopwords.contains($0) }
    }

    /// La palabra y sus posibles singulares: "tomates" → tomates, tomat, tomate.
    private static func forms(of token: String) -> [String] {
        var result = [token]
        for suffix in ["es", "s"] where token.hasSuffix(suffix) {
            let singular = String(token.dropLast(suffix.count))
            if singular.count >= 3 { result.append(singular) }
        }
        return result
    }
}
