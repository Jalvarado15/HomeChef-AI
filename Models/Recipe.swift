//
//  Recipe.swift
//  HomeChef AI
//
//  Modelo de datos para recetas generadas por IA (MVP Core).
//  Esquema exacto definido por Gemini — sin campos adicionales.
//

import Foundation
import SwiftData

@Model
final class Recipe {
    @Attribute(.unique) var id: UUID
    var title: String
    var content: String
    var isSaved: Bool
    var generatedDate: Date

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        isSaved: Bool = false,
        generatedDate: Date = .now
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.isSaved = isSaved
        self.generatedDate = generatedDate
    }
}
