//
//  IngredientMatcher.swift
//  HomeChef AI
//
//  Función pura que decide si un producto del inventario aparece mencionado
//  en el texto de una receta. Usa la misma normalización que el clasificador
//  de categorías: ignora mayúsculas, tildes y plurales simples.
//
//  Como Recipe guarda el contenido como texto libre (sin lista estructurada
//  de ingredientes), la coincidencia se busca dentro de ese texto. Un producto
//  coincide si alguna de sus palabras significativas aparece como palabra
//  completa ("Pechuga de pollo" coincide con una receta que dice "pollo").
//

import Foundation

enum IngredientMatcher {

    /// Palabras que no identifican un ingrediente por sí solas.
    private static let stopwords: Set<String> = [
        "de", "del", "la", "el", "los", "las", "con", "en", "y", "al",
        "para", "sin", "un", "una", "por"
    ]

    /// `true` si alguna palabra significativa de `itemName` aparece en `recipeText`.
    static func matches(itemName: String, in recipeText: String) -> Bool {
        let recipeForms = Set(tokens(of: recipeText).flatMap(forms(of:)))

        return tokens(of: itemName)
            .filter { $0.count >= 3 && !stopwords.contains($0) }
            .contains { token in
                forms(of: token).contains { recipeForms.contains($0) }
            }
    }

    // MARK: - Normalización

    private static func tokens(of text: String) -> [String] {
        CulinaryPreferences.fold(text)
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
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
