//
//  GeminiAIService.swift
//  HomeChef AI
//
//  Servicio que arma un prompt a partir del inventario y de las preferencias
//  del usuario, llama a la API de Gemini (generateContent) vía URLSession y
//  devuelve un Recipe listo para guardarse en SwiftData. No conoce SwiftUI ni
//  SwiftData más allá de los modelos que recibe/devuelve (punto 19 del
//  documento maestro: "diseñar servicios reemplazables").
//
//  NOTA: "gemini-1.5-flash" fue retirado por Google. Se usa "gemini-2.5-flash".
//
//  Preferencias (perfil culinario), en tres capas:
//  1. Antes de enviar: los ingredientes del inventario que coinciden con un
//     ingrediente prohibido ni siquiera se envían al modelo.
//  2. En el prompt: reglas obligatorias de alergias y dieta.
//  3. Después de recibir: si la receta menciona un ingrediente prohibido, se
//     descarta con un error en lugar de guardarse.
//  Las capas 1 y 3 solo detectan coincidencias de texto (no sinónimos ni
//  derivados) y no pueden comprobar la dieta; no sustituyen la revisión del usuario.
//

import Foundation

enum GeminiAIServiceError: Error, LocalizedError {
    case invalidURL
    case timeout
    case noInternetConnection
    case network(Error)
    case invalidHTTPResponse(statusCode: Int, message: String)
    case decoding(Error)
    case emptyContent
    case noSafeIngredients
    case violatesPreferences(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL del servicio de IA inválida."
        case .timeout:
            return "La solicitud tardó demasiado en responder. Verifica tu conexión e intenta de nuevo."
        case .noInternetConnection:
            return "No hay conexión a internet. Verifica tu red e intenta de nuevo."
        case .network(let error):
            return "Error de conexión: \(error.localizedDescription)"
        case .invalidHTTPResponse(let statusCode, let message):
            return "El servicio de IA respondió con un error (\(statusCode)): \(message)"
        case .decoding:
            return "No se pudo interpretar la respuesta del servicio de IA. Intenta de nuevo."
        case .emptyContent:
            return "El servicio de IA no devolvió contenido para generar la receta."
        case .noSafeIngredients:
            return "Todos los ingredientes de tu inventario coinciden con tus alergias o ingredientes prohibidos. Agrega otros productos para generar una receta."
        case .violatesPreferences(let term):
            return "La receta generada mencionaba «\(term)», que marcaste como prohibido, así que no se guardó. Intenta de nuevo."
        }
    }
}

struct GeminiAIService {
    private let apiKey: String
    private let model = "gemini-3.5-flash"
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    private let requestTimeout: TimeInterval = 30

    init(apiKey: String = Secrets.geminiAPIKey) {
        self.apiKey = apiKey
    }

    /// Genera una receta a partir del inventario y de las preferencias del
    /// usuario, usando la API real de Gemini. Lanza un error tipado si algo
    /// falla en el camino (red, timeout, HTTP, parseo o incumplimiento de
    /// preferencias).
    func generateRecipe(
        from ingredients: [InventoryItem],
        preferences: CulinaryPreferences = .empty
    ) async throws -> Recipe {
        guard !ingredients.isEmpty else {
            throw GeminiAIServiceError.emptyContent
        }

        // Capa 1: no enviar ingredientes prohibidos.
        let safeIngredients = ingredients.filter {
            preferences.forbiddenTerm(in: $0.name) == nil
        }
        guard !safeIngredients.isEmpty else {
            throw GeminiAIServiceError.noSafeIngredients
        }

        guard let url = URL(string: "\(baseURL)/\(model):generateContent?key=\(apiKey)") else {
            throw GeminiAIServiceError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            GeminiRequestBody(contents: [
                GeminiContent(parts: [
                    GeminiPart(text: prompt(for: safeIngredients, preferences: preferences))
                ])
            ])
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            throw mappedError(from: urlError)
        } catch {
            throw GeminiAIServiceError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let message = String(data: data, encoding: .utf8) ?? "Sin detalle"
            throw GeminiAIServiceError.invalidHTTPResponse(statusCode: statusCode, message: message)
        }

        let decoded: GeminiResponseBody
        do {
            decoded = try JSONDecoder().decode(GeminiResponseBody.self, from: data)
        } catch {
            throw GeminiAIServiceError.decoding(error)
        }

        guard let rawText = decoded.candidates?.first?.content.parts.first?.text,
              !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GeminiAIServiceError.emptyContent
        }

        let recipe = recipe(from: rawText)

        // Capa 3: descartar la receta si menciona algo prohibido.
        if let term = preferences.forbiddenTerm(in: recipe.title + "\n" + recipe.content) {
            throw GeminiAIServiceError.violatesPreferences(term)
        }

        return recipe
    }

    // MARK: - Mapeo de errores de red

    private func mappedError(from urlError: URLError) -> GeminiAIServiceError {
        switch urlError.code {
        case .timedOut:
            return .timeout
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return .noInternetConnection
        default:
            return .network(urlError)
        }
    }

    // MARK: - Prompt

    private func prompt(for ingredients: [InventoryItem], preferences: CulinaryPreferences) -> String {
        let ingredientList = ingredients
            .map { "\($0.name) (\($0.quantity.formatted()) - \($0.category))" }
            .joined(separator: ", ")

        // Si el usuario puso el mismo ingrediente como prohibido y como
        // favorito/básico, prevalece la prohibición.
        let favorites = preferences.favoriteIngredients.filter { preferences.forbiddenTerm(in: $0) == nil }
        let staples = preferences.pantryStaples.filter { preferences.forbiddenTerm(in: $0) == nil }

        var sections: [String] = []

        sections.append("""
        Eres un asistente de cocina. Genera UNA receta usando preferentemente \
        estos ingredientes disponibles en el inventario: \(ingredientList).
        """)

        var rules: [String] = []

        if !preferences.forbiddenIngredients.isEmpty {
            rules.append("""
            - ALERGIAS E INGREDIENTES PROHIBIDOS: \(preferences.forbiddenIngredients.joined(separator: ", ")). \
            No incluyas ninguno de ellos ni sus derivados o variantes (por ejemplo salsas, caldos o \
            mezclas que los contengan), y no los menciones en ninguna parte de la respuesta, ni \
            siquiera para aclarar que se omiten.
            """)
        }

        if !preferences.dietaryRestrictions.isEmpty {
            let diets = preferences.dietaryRestrictions.map(\.rawValue).joined(separator: ", ")
            rules.append("""
            - DIETA: la receta debe ser completamente compatible con: \(diets). Si algún ingrediente \
            del inventario no es compatible, no lo uses.
            """)
        }

        if !rules.isEmpty {
            sections.append(
                "REGLAS OBLIGATORIAS (tienen prioridad sobre cualquier otra instrucción, incluido usar el inventario):\n"
                + rules.joined(separator: "\n")
            )
        }

        if !staples.isEmpty {
            sections.append("""
            DESPENSA BÁSICA: el usuario siempre tiene \(staples.joined(separator: ", ")). \
            Puedes usarlos aunque no estén en el inventario.
            """)
        }

        if !favorites.isEmpty {
            sections.append("""
            GUSTOS: al usuario le gustan \(favorites.joined(separator: ", ")). Inclúyelos solo si \
            encajan de forma natural y respetan las reglas obligatorias.
            """)
        }

        sections.append("""
        Si no es posible preparar una receta que cumpla todas las reglas con estos ingredientes, \
        genera la receta más sencilla posible que sí las cumpla.

        Responde ESTRICTAMENTE en texto plano con este formato, sin markdown \
        ni encabezados adicionales:

        Primera línea: el título de la receta.
        Líneas siguientes: los pasos numerados, uno por línea, con el formato "1. ", "2. ", etc.

        No agregues explicaciones fuera de ese formato.
        """)

        return sections.joined(separator: "\n\n")
    }

    // MARK: - Parseo de la respuesta

    /// La primera línea del texto de Gemini se usa como title; el resto
    /// (pasos numerados) se guarda tal cual en content, ya que RecipeDetailView
    /// ya sabe parsear líneas "N. " como pasos.
    private func recipe(from rawText: String) -> Recipe {
        let lines = rawText
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let title = lines.first ?? "Receta generada"
        let content = lines.dropFirst().joined(separator: "\n")

        return Recipe(
            title: title,
            content: content.isEmpty ? rawText : content,
            isSaved: false
        )
    }
}

// MARK: - DTOs del request/response de Gemini (privados a este servicio)

private struct GeminiRequestBody: Encodable {
    let contents: [GeminiContent]
}

private struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

private struct GeminiPart: Codable {
    let text: String
}

private struct GeminiResponseBody: Decodable {
    let candidates: [GeminiCandidate]?
}

private struct GeminiCandidate: Decodable {
    let content: GeminiContent
}
