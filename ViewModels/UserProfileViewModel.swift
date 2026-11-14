//
//  UserProfileViewModel.swift
//  HomeChef AI
//
//  Lógica de edición del perfil culinario: restricciones dietéticas y las
//  tres listas de texto (prohibidos, favoritos, despensa básica).
//
//  Persistencia: cada cambio se guarda de inmediato con `context.save()`
//  (no se depende del autosave de SwiftData, que puede no ejecutarse si la
//  app se cierra enseguida). El perfil se inserta explícitamente la primera
//  vez y, si por algún motivo hubiera más de uno, se consolidan en uno solo.
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

    /// Garantiza que exista exactamente un UserProfile en SwiftData.
    /// Consulta el contexto directamente (no depende de un arreglo @Query
    /// que podría estar desactualizado), inserta el perfil si falta y, si
    /// hay duplicados, conserva el que tenga más datos y elimina el resto.
    func ensureProfileExists(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []

        guard let keeper = existing.max(by: { contentCount($0) < contentCount($1) }) else {
            context.insert(UserProfile())
            save(context)
            return
        }

        let duplicates = existing.filter { $0 !== keeper }
        guard !duplicates.isEmpty else { return }

        duplicates.forEach { context.delete($0) }
        save(context)
    }

    // MARK: - Restricciones dietéticas

    func isSelected(_ restriction: DietaryRestriction, in profile: UserProfile) -> Bool {
        profile.dietaryRestrictionIDs.contains(restriction.rawValue)
    }

    func setRestriction(
        _ restriction: DietaryRestriction,
        isOn: Bool,
        in profile: UserProfile,
        context: ModelContext
    ) {
        var ids = profile.dietaryRestrictionIDs
        ids.removeAll { $0 == restriction.rawValue }
        if isOn { ids.append(restriction.rawValue) }
        profile.dietaryRestrictionIDs = ids
        save(context)
    }

    // MARK: - Listas de texto

    func canAddDraft(for kind: ProfileListKind) -> Bool {
        !CulinaryPreferences.clean(drafts[kind] ?? "").isEmpty
    }

    /// Agrega el texto en edición a la lista: lo limpia, ignora duplicados
    /// (sin distinguir mayúsculas ni tildes) y respeta el máximo de elementos.
    func addDraft(for kind: ProfileListKind, to profile: UserProfile, context: ModelContext) {
        let item = CulinaryPreferences.clean(drafts[kind] ?? "")
        guard !item.isEmpty else { return }

        var items = profile[keyPath: kind.keyPath]
        guard items.count < CulinaryPreferences.maxItems else { return }

        let folded = CulinaryPreferences.fold(item)
        let isDuplicate = items.contains { CulinaryPreferences.fold($0) == folded }

        if !isDuplicate {
            items.append(item)
            profile[keyPath: kind.keyPath] = items
            save(context)
        }
        drafts[kind] = ""
    }

    func remove(
        at offsets: IndexSet,
        from kind: ProfileListKind,
        in profile: UserProfile,
        context: ModelContext
    ) {
        var items = profile[keyPath: kind.keyPath]
        for index in offsets.sorted(by: >) where items.indices.contains(index) {
            items.remove(at: index)
        }
        profile[keyPath: kind.keyPath] = items
        save(context)
    }

    // MARK: - Helpers

    private func save(_ context: ModelContext) {
        try? context.save()
    }

    private func contentCount(_ profile: UserProfile) -> Int {
        profile.dietaryRestrictionIDs.count
            + profile.forbiddenIngredients.count
            + profile.favoriteIngredients.count
            + profile.pantryStaples.count
    }
}
