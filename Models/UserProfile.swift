//
//  UserProfile.swift
//  HomeChef AI
//
//  Perfil culinario del usuario, persistido localmente con SwiftData.
//  Se usa una única instancia por dispositivo.
//
//  Propiedades persistidas (no renombrar sin migración):
//  - dietaryRestrictionIDs: rawValues de DietaryRestriction
//  - forbiddenIngredients:  alergias e ingredientes prohibidos
//  - favoriteIngredients:   ingredientes favoritos
//  - pantryStaples:         despensa básica
//  - outOfStockBasics:      subconjunto de pantryStaples marcado como agotado
//
//  Al mutar un arreglo se reasigna siempre una copia completa.
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID = UUID()
    var dietaryRestrictionIDs: [String] = []
    var forbiddenIngredients: [String] = []
    var favoriteIngredients: [String] = []
    var pantryStaples: [String] = []
    var outOfStockBasics: [String] = []

    init(
        id: UUID = UUID(),
        dietaryRestrictionIDs: [String] = [],
        forbiddenIngredients: [String] = [],
        favoriteIngredients: [String] = [],
        pantryStaples: [String] = [],
        outOfStockBasics: [String] = []
    ) {
        self.id = id
        self.dietaryRestrictionIDs = dietaryRestrictionIDs
        self.forbiddenIngredients = forbiddenIngredients
        self.favoriteIngredients = favoriteIngredients
        self.pantryStaples = pantryStaples
        self.outOfStockBasics = outOfStockBasics
    }

    /// Foto inmutable y limpia de las preferencias, lista para el servicio de IA.
    /// Solo incluye los básicos que NO están agotados.
    var preferences: CulinaryPreferences {
        let outOfStock = Set(outOfStockBasics.map(CulinaryPreferences.fold))

        return CulinaryPreferences(
            dietaryRestrictions: DietaryRestriction.allCases.filter {
                dietaryRestrictionIDs.contains($0.rawValue)
            },
            forbiddenIngredients: CulinaryPreferences.cleaned(forbiddenIngredients),
            favoriteIngredients: CulinaryPreferences.cleaned(favoriteIngredients),
            pantryStaples: CulinaryPreferences.cleaned(pantryStaples).filter {
                !outOfStock.contains(CulinaryPreferences.fold($0))
            }
        )
    }
}
