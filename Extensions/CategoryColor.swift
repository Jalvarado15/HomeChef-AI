//
//  CategoryColor.swift
//  HomeChef AI
//
//  Asigna un color consistente a cada categoría de inventario, a partir de
//  una paleta curada (evita colores aleatorios/aleatoriedad visual entre
//  relanzamientos de la app). El mismo nombre de categoría siempre produce
//  el mismo color.
//

import SwiftUI

extension String {
    /// Color asociado a esta categoría, tomado de una paleta fija tipo despensa.
    var categoryColor: Color {
        let palette: [Color] = [
            Color(red: 0.30, green: 0.45, blue: 0.32),  // basil
            Color(red: 0.78, green: 0.60, blue: 0.24),  // wheat
            Color(red: 0.72, green: 0.35, blue: 0.29),  // clay
            Color(red: 0.32, green: 0.38, blue: 0.55),  // blueberry
            Color(red: 0.48, green: 0.32, blue: 0.45),  // plum
            Color(red: 0.38, green: 0.42, blue: 0.44)   // slate
        ]

        guard !isEmpty else { return palette[0] }

        let hash = unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[hash % palette.count]
    }
}
