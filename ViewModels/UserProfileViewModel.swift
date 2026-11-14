//
//  UserProfileViewModel.swift
//  HomeChef AI
//
//  Lógica de edición del perfil culinario: restricciones dietéticas y las
//  tres listas de texto (prohibidos, favoritos, despensa básica). La vista
//  solo muestra y delega aquí; los cambios se aplican en vivo al @Model.
//

import Foundation
import SwiftData

/// Las tres listas editables del perfil.
enum ProfileListKind: CaseIterable {
    case forbidden
    case favorite
    case staple

    var keyPath: ReferenceWritableKeyPath<UserProfile, [String]> {
        switch self {
        case .forbidden: return \.forbiddenIngredients
        case .favorite: return \.favoriteIngredients
        case .staple: return \.pantryStaples
        }
    }
}

@Observable
final class UserProfileViewModel {

    /// Texto en edición de cada lista.
    var drafts: [ProfileListKind: String] = [:]

    // MARK: - Perfil único

    /// Crea el perfil la primera vez que se abre la pantalla.
    func ensureProfileExists(in profiles: [UserProfile], context: ModelContext) {
        guard profiles.isEmpty else { return }
        context.insert(UserProfile())
    }

    // MARK: - Restricciones dietéticas

    func isSelected(_ restriction: DietaryRestriction, in profile: UserProfile) -> Bool {
        profile.dietaryRestrictionIDs.contains(restriction.rawValue)
    }

    func setRestriction(_ restriction: DietaryRestriction, isOn: Bool, in profile: UserProfile) {
        var ids = profile.dietaryRestrictionIDs
        ids.removeAll { $0 == restriction.rawValue }
        if isOn { ids.append(restriction.rawValue) }
        profile.dietaryRestrictionIDs = ids
    }

    // MARK: - Listas de texto

    func canAddDraft(for kind: ProfileListKind) -> Bool {
        !CulinaryPreferences.clean(drafts[kind] ?? "").isEmpty
    }

    /// Agrega el texto en edición a la lista: lo limpia, ignora duplicados
    /// (sin distinguir mayúsculas ni tildes) y respeta el máximo de elementos.
    func addDraft(for kind: ProfileListKind, to profile: UserProfile) {
        let item = CulinaryPreferences.clean(drafts[kind] ?? "")
        guard !item.isEmpty else { return }

        var items = profile[keyPath: kind.keyPath]
        guard items.count < CulinaryPreferences.maxItems else { return }

        let folded = CulinaryPreferences.fold(item)
        let isDuplicate = items.contains { CulinaryPreferences.fold($0) == folded }

        if !isDuplicate {
            items.append(item)
            profile[keyPath: kind.keyPath] = items
        }
        drafts[kind] = ""
    }

    func remove(at offsets: IndexSet, from kind: ProfileListKind, in profile: UserProfile) {
        var items = profile[keyPath: kind.keyPath]
        for index in offsets.sorted(by: >) where items.indices.contains(index) {
            items.remove(at: index)
        }
        profile[keyPath: kind.keyPath] = items
    }
}
