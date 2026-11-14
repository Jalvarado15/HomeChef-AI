//
//  IngredientCategory.swift
//  HomeChef AI
//
//  Categorías estandarizadas para el inventario y clasificador local
//  basado en palabras clave en español. El modelo InventoryItem sigue
//  guardando la categoría como String (rawValue), sin cambios de esquema.
//

import Foundation

enum IngredientCategory: String, CaseIterable, Identifiable {
    case proteinas = "Proteínas"
    case vegetalesYFrutas = "Vegetales y Frutas"
    case lacteos = "Lácteos"
    case granosYHarinas = "Granos y Harinas"
    case condimentosYAceites = "Condimentos y Aceites"
    case conservas = "Conservas"
    case bebidas = "Bebidas"
    case otros = "Otros"

    var id: String { rawValue }

    /// Convierte el String guardado en un InventoryItem a una categoría
    /// estándar. Si es un valor antiguo (texto libre, p. ej. "Verduras"),
    /// intenta mapearlo por palabras clave y, si no puede, usa `.otros`.
    init(storedValue: String) {
        let folded = Self.fold(storedValue)
        if let exact = Self.allCases.first(where: { Self.fold($0.rawValue) == folded }) {
            self = exact
        } else {
            self = Self.suggestCategory(for: storedValue)
        }
    }

    // MARK: - Clasificador local

    /// Función pura: sugiere una categoría a partir del nombre del producto.
    /// Revisa las palabras de izquierda a derecha y gana la primera que
    /// coincida (en español el sustantivo principal suele ir primero:
    /// "salsa de tomate" → Condimentos, "jugo de naranja" → Bebidas).
    /// Ignora tildes, mayúsculas y plurales simples.
    static func suggestCategory(for name: String) -> IngredientCategory {
        let tokens = fold(name)
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }

        for token in tokens {
            if let category = category(forToken: token) {
                return category
            }
        }
        return .otros
    }

    private static func category(forToken token: String) -> IngredientCategory? {
        if let category = keywordMap[token] { return category }

        // Plurales simples: "huevos" → "huevo", "tomates" → "tomate".
        for suffix in ["es", "s"] where token.hasSuffix(suffix) {
            let singular = String(token.dropLast(suffix.count))
            if let category = keywordMap[singular] { return category }
        }
        return nil
    }

    private static func fold(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Palabras clave (sin tildes, en minúscula) por categoría. Si una palabra
    /// aparece en dos grupos, gana el primero de la lista.
    private static let keywordMap: [String: IngredientCategory] = {
        let groups: [(IngredientCategory, [String])] = [
            (.proteinas, [
                "pollo", "pechuga", "muslo", "carne", "res", "cerdo", "chancho",
                "cordero", "pavo", "bistec", "pescado", "salmon", "atun", "tilapia",
                "sardina", "camaron", "marisco", "huevo", "jamon", "tocino",
                "salchicha", "chorizo", "tofu", "proteina"
            ]),
            (.lacteos, [
                "leche", "queso", "yogur", "yogurt", "mantequilla", "crema",
                "natilla", "requeson", "margarina", "helado", "lacteo"
            ]),
            (.granosYHarinas, [
                "arroz", "pasta", "espagueti", "fideo", "macarron", "pan",
                "tortilla", "harina", "avena", "cereal", "frijol", "lenteja",
                "garbanzo", "maiz", "galleta", "quinoa", "trigo", "cebada",
                "polenta", "grano"
            ]),
            (.condimentosYAceites, [
                "sal", "pimienta", "azucar", "aceite", "vinagre", "salsa",
                "mayonesa", "mostaza", "ketchup", "catsup", "canela", "comino",
                "oregano", "curry", "paprika", "pimenton", "condimento",
                "especia", "miel", "consome", "caldo", "sazonador", "achiote",
                "laurel", "albahaca"
            ]),
            (.conservas, [
                "lata", "enlatado", "conserva", "pepinillo", "aceituna",
                "mermelada", "compota"
            ]),
            (.bebidas, [
                "agua", "jugo", "refresco", "gaseosa", "cafe", "te", "cerveza",
                "vino", "licor", "soda", "bebida", "energizante", "batido"
            ]),
            (.vegetalesYFrutas, [
                "tomate", "cebolla", "ajo", "papa", "zanahoria", "lechuga",
                "pepino", "chile", "pimiento", "brocoli", "espinaca", "apio",
                "culantro", "cilantro", "yuca", "camote", "platano", "banano",
                "manzana", "naranja", "limon", "pera", "uva", "fresa", "mango",
                "pina", "sandia", "melon", "papaya", "aguacate", "calabaza",
                "ayote", "chayote", "elote", "cebollin", "remolacha", "repollo",
                "coliflor", "hongo", "champinon", "mora", "durazno", "kiwi",
                "verdura", "fruta", "vegetal"
            ])
        ]

        var map: [String: IngredientCategory] = [:]
        for (category, keywords) in groups {
            for keyword in keywords where map[keyword] == nil {
                map[keyword] = category
            }
        }
        return map
    }()
}
