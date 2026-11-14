//
//  CulinaryPreferences.swift
//  HomeChef AI
//
//  Restricciones dietéticas y "foto" inmutable de las preferencias del usuario.
//  Es un struct simple (no un @Model) para que GeminiAIService no dependa de
//  SwiftData y el servicio siga siendo reemplazable.
//

import Foundation

enum DietaryRestriction: String, CaseIterable, Identifiable, Sendable {
    case vegetariano = "Vegetariano"
    case vegano = "Vegano"
    case sinGluten = "Sin Gluten"
    case sinLactosa = "Sin Lactosa"
    case keto = "Keto"

    var id: String { rawValue }
}

struct CulinaryPreferences: Equatable, Sendable {
    var dietaryRestrictions: [DietaryRestriction] = []
    var forbiddenIngredients: [String] = []
    var favoriteIngredients: [String] = []
    var pantryStaples: [String] = []

    static let empty = CulinaryPreferences()

    // MARK: - Límites y limpieza de texto del usuario

    static let maxItemLength = 40
    static let maxItems = 30

    /// Normaliza un texto escrito por el usuario antes de guardarlo o de
    /// enviarlo en el prompt: una sola línea, sin comillas dobles y con
    /// longitud acotada.
    static func clean(_ raw: String) -> String {
        let singleLine = raw
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(singleLine.prefix(maxItemLength))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func cleaned(_ items: [String]) -> [String] {
        items.map(clean).filter { !$0.isEmpty }
    }

    /// Minúsculas y sin tildes, para comparar textos en español.
    static func fold(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Detección de ingredientes prohibidos

    /// Devuelve el primer ingrediente prohibido que aparece como palabra
    /// completa en `text` (ignora tildes, mayúsculas y plurales simples),
    /// o `nil` si no hay coincidencias. Es una verificación local de apoyo:
    /// no detecta sinónimos ni derivados.
    func forbiddenTerm(in text: String) -> String? {
        let haystack = Self.fold(text)
        for term in forbiddenIngredients {
            let needle = Self.fold(term)
            guard !needle.isEmpty else { continue }
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: needle) + "(?:e?s)?\\b"
            if haystack.range(of: pattern, options: .regularExpression) != nil {
                return term
            }
        }
        return nil
    }
}
