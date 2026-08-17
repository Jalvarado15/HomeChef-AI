//
//  InventoryItem.swift
//  HomeChef AI
//
//  Modelo de datos para el inventario manual (MVP Core).
//  Esquema exacto definido por Gemini — sin campos adicionales.
//

import Foundation
import SwiftData

@Model
final class InventoryItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var quantity: Double
    var category: String
    var dateAdded: Date

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double,
        category: String,
        dateAdded: Date = .now
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.category = category
        self.dateAdded = dateAdded
    }
}
