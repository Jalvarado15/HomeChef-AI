//
//  UserProfile.swift
//  HomeChef AI
//
//  Perfil culinario del usuario, persistido localmente con SwiftData.
//  Se usa una única instancia por dispositivo.
//
//  Las restricciones dietéticas se guardan como rawValues (String) para que
//  el almacenamiento no dependa del enum si más adelante cambia.
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var dietaryRestrictionIDs: [String]
    var forbiddenIngredients: [String]
    var favoriteIngredients: [String]
    var pantryStaples: [String]

    init(
        id: UUID = UUID(),
        dietaryRestrictionIDs: [String] = [],
        forbiddenIngredients: [String] = [],
        favoriteIngredients: [String] = [],
        pantryStaples: [String] = []
    ) {
        self.id = id
        self.dietaryRestrictionIDs = dietaryRestrictionIDs
        self.forbiddenIngredients = forbiddenIngredients
        self.favoriteIngredients = favoriteIngredients
        self.pantryStaples = pantryStaples
    }

    /// Foto inmutable y ya limpia de las preferencias, lista para el servicio de IA.
    var preferences: CulinaryPreferences {
        CulinaryPreferences(
            dietaryRestrictions: DietaryRestriction.allCases.filter {
                dietaryRestrictionIDs.contains($0.rawValue)
            },
            forbiddenIngredients: CulinaryPreferences.cleaned(forbiddenIngredients),
            favoriteIngredients: CulinaryPreferences.cleaned(favoriteIngredients),
            pantryStaples: CulinaryPreferences.cleaned(pantryStaples)
        )
    }
}
