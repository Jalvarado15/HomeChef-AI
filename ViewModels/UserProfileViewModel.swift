//
//  UserProfileViewModel.swift
//  HomeChef AI
//
//  Lógica de edición del perfil culinario.
//
//  - El ViewModel guarda el perfil ACTIVO (`profile`): es la misma instancia
//    que consulta y modifica, y la que muestra la vista.
//  - Los arreglos nunca se mutan en sitio: se toma una copia, se modifica y
//    se reasigna completa a la propiedad del @Model.
//  - Cada cambio se guarda de inmediato con `context.save()`. Si el guardado
//    falla, el error queda registrado en la consola de Xcode (categoría
//    "UserProfile") en lugar de perderse en silencio.
//

import Foundation
import SwiftData
import os

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

    /// Perfil activo. Es `nil` hasta que se llama a `ensureProfileExists`.
    private(set) var profile: UserProfile?

    /// Texto en edición de cada lista.
    var drafts: [ProfileListKind: String] = [:]

    private let logger = Logger(subsystem: "HomeChefAI", category: "UserProfile")

    // MARK: - Perfil único

    /// Garantiza que exista exactamente un UserProfile en SwiftData y lo deja
    /// como perfil activo.
    /// - Consulta el contexto directamente (no depende de un @Query).
    /// - Si no existe, lo inserta explícitamente y guarda.
    /// - Si hay duplicados, conserva el que tenga más datos y elimina el resto.
    /// - Normaliza los arreglos de una sesión previa (vacíos, repetidos, texto
    ///   sobrante) reasignándolos solo si algo cambió.
    func ensureProfileExists(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []

        let active: UserProfile
        if let keeper = existing.max(by: { contentCount($0) < contentCount($1) }) {
            active = keeper

            let duplicates = existing.filter { $0 !== keeper }
            duplicates.forEach { context.delete($0) }

            let normalized = normalize(active)
            if !duplicates.isEmpty || normalized {
                save(context)
            }
        } else {
            active = UserProfile()
            context.insert(active)
            save(context)
        }

        profile = active
        logger.debug("""
        Perfil cargado: \(active.dietaryRestrictionIDs.count) restricciones, \
        \(active.forbiddenIngredients.count) prohibidos, \
        \(active.favoriteIngredients.count) favoritos, \
        \(active.pantryStaples.count) básicos
        """)
    }

    // MARK: - Lectura

    func isSelected(_ restriction: DietaryRestriction) -> Bool {
        profile?.dietaryRestrictionIDs.contains(restriction.rawValue) ?? false
    }

    func items(for kind: ProfileListKind) -> [String] {
        profile?[keyPath: kind.keyPath] ?? []
    }

    func canAddDraft(for kind: ProfileListKind) -> Bool {
        !CulinaryPreferences.clean(drafts[kind] ?? "").isEmpty
    }

    // MARK: - Stock de básicos

    func isOutOfStock(_ item: String) -> Bool {
        let key = CulinaryPreferences.fold(item)
        return profile?.outOfStockBasics.contains { CulinaryPreferences.fold($0) == key } ?? false
    }

    /// Alterna un básico entre disponible y agotado.
    func toggleOutOfStock(_ item: String, context: ModelContext) {
        guard let profile else { return }

        let key = CulinaryPreferences.fold(item)
        var outOfStock = profile.outOfStockBasics

        if outOfStock.contains(where: { CulinaryPreferences.fold($0) == key }) {
            outOfStock.removeAll { CulinaryPreferences.fold($0) == key }
        } else {
            outOfStock.append(item)
        }

        profile.outOfStockBasics = outOfStock   // copia nueva reasignada
        save(context)
    }

    // MARK: - Restricciones dietéticas

    func setRestriction(_ restriction: DietaryRestriction, isOn: Bool, context: ModelContext) {
        guard let profile else { return }

        var ids = profile.dietaryRestrictionIDs
        ids.removeAll { $0 == restriction.rawValue }
        if isOn { ids.append(restriction.rawValue) }

        profile.dietaryRestrictionIDs = ids   // copia nueva reasignada
        save(context)
    }

    // MARK: - Listas de texto

    /// Agrega el texto en edición a la lista: lo limpia, ignora duplicados
    /// (sin distinguir mayúsculas ni tildes) y respeta el máximo de elementos.
    func addDraft(for kind: ProfileListKind, context: ModelContext) {
        guard let profile else { return }

        let item = CulinaryPreferences.clean(drafts[kind] ?? "")
        guard !item.isEmpty else { return }

        var items = profile[keyPath: kind.keyPath]
        guard items.count < CulinaryPreferences.maxItems else { return }

        let folded = CulinaryPreferences.fold(item)
        let isDuplicate = items.contains { CulinaryPreferences.fold($0) == folded }

        if !isDuplicate {
            items.append(item)
            profile[keyPath: kind.keyPath] = items   // copia nueva reasignada
            save(context)
        }
        drafts[kind] = ""
    }

    func remove(at offsets: IndexSet, from kind: ProfileListKind, context: ModelContext) {
        guard let profile else { return }

        var items = profile[keyPath: kind.keyPath]
        for index in offsets.sorted(by: >) where items.indices.contains(index) {
            items.remove(at: index)
        }

        profile[keyPath: kind.keyPath] = items   // copia nueva reasignada
        if kind == .staple { pruneOutOfStock(profile) }
        save(context)
    }

    /// Agrega lo que el usuario haya escrito sin pulsar "+" ni Intro, para no
    /// perderlo al cerrar la pantalla.
    func commitPendingDrafts(context: ModelContext) {
        for kind in ProfileListKind.allCases {
            addDraft(for: kind, context: context)
        }
    }

    // MARK: - Helpers

    @discardableResult
    private func save(_ context: ModelContext) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            logger.error("No se pudo guardar el perfil: \(error.localizedDescription)")
            return false
        }
    }

    /// Deja en `outOfStockBasics` solo los elementos que siguen en la despensa
    /// (sin repetidos). Devuelve `true` si cambió algo.
    @discardableResult
    private func pruneOutOfStock(_ profile: UserProfile) -> Bool {
        let stapleKeys = Set(profile.pantryStaples.map(CulinaryPreferences.fold))

        var seen = Set<String>()
        let pruned = profile.outOfStockBasics.filter {
            let key = CulinaryPreferences.fold($0)
            return stapleKeys.contains(key) && seen.insert(key).inserted
        }

        guard pruned != profile.outOfStockBasics else { return false }
        profile.outOfStockBasics = pruned   // copia nueva reasignada
        return true
    }

    private func contentCount(_ profile: UserProfile) -> Int {
        profile.dietaryRestrictionIDs.count
            + profile.forbiddenIngredients.count
            + profile.favoriteIngredients.count
            + profile.pantryStaples.count
    }

    /// Limpia los arreglos del perfil. Devuelve `true` si cambió algo.
    private func normalize(_ profile: UserProfile) -> Bool {
        var changed = false

        for kind in ProfileListKind.allCases {
            let current = profile[keyPath: kind.keyPath]
            let cleaned = uniqueCleaned(current)
            if cleaned != current {
                profile[keyPath: kind.keyPath] = cleaned
                changed = true
            }
        }

        var seenIDs = Set<String>()
        let validIDs = profile.dietaryRestrictionIDs.filter {
            DietaryRestriction(rawValue: $0) != nil && seenIDs.insert($0).inserted
        }
        if validIDs != profile.dietaryRestrictionIDs {
            profile.dietaryRestrictionIDs = validIDs
            changed = true
        }

        if pruneOutOfStock(profile) { changed = true }

        return changed
    }

    private func uniqueCleaned(_ items: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for raw in items {
            let item = CulinaryPreferences.clean(raw)
            let key = CulinaryPreferences.fold(item)
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            result.append(item)
            if result.count == CulinaryPreferences.maxItems { break }
        }
        return result
    }
}
