//
//  GeminiAIService.swift
//  HomeChef AI
//
//  Servicio que arma un prompt a partir del inventario, llama a la API de
//  Gemini (generateContent) vía URLSession y devuelve un Recipe listo para
//  guardarse en SwiftData. No conoce SwiftUI ni el ModelContext: solo hace
//  la llamada de red y el parseo, para mantenerlo reemplazable (punto 19
//  del documento maestro: "diseñar servicios reemplazables").
//
//  NOTA: "gemini-1.5-flash" fue retirado por Google. Se usa "gemini-2.5-flash",
//  el modelo estable equivalente disponible actualmente.
//

import Foundation

enum GeminiAIServiceError: Error, LocalizedError {
    case invalidURL
    case network(Error)
    case invalidHTTPResponse(statusCode: Int, message: String)
    case decoding(Error)
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL del servicio de IA inválida."
        case .network(let error):
            return "Error de conexión: \(error.localizedDescription)"
        case .invalidHTTPResponse(let statusCode, let message):
            return "El servicio de IA respondió con un error (\(statusCode)): \(message)"
        case .decoding:
            return "No se pudo interpretar la respuesta del servicio de IA."
        case .emptyContent:
            return "El servicio de IA no devolvió contenido para generar la receta."
        }
    }
}

struct GeminiAIService {
    private let apiKey: String
    private let model = "gemini-3.5-flash"
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    init(apiKey: String = Secrets.geminiAPIKey) {
        self.apiKey = apiKey
    }

    /// Genera una receta a partir de los ingredientes del inventario, usando
    /// la API real de Gemini. Lanza un error tipado si algo falla en el
    /// camino (red, HTTP, parseo).
    func generateRecipe(from ingredients: [InventoryItem]) async throws -> Recipe {
        guard !ingredients.isEmpty else {
            throw GeminiAIServiceError.emptyContent
        }

        guard let url = URL(string: "\(baseURL)/\(model):generateContent?key=\(apiKey)") else {
            throw GeminiAIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            GeminiRequestBody(contents: [
                GeminiContent(parts: [GeminiPart(text: prompt(for: ingredients))])
            ])
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
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

        return recipe(from: rawText)
    }

    // MARK: - Prompt

    private func prompt(for ingredients: [InventoryItem]) -> String {
        let ingredientList = ingredients
            .map { "\($0.name) (\($0.quantity.formatted()) - \($0.category))" }
            .joined(separator: ", ")

        return """
        Eres un asistente de cocina. Genera UNA receta usando preferentemente \
        estos ingredientes disponibles en el inventario: \(ingredientList).

        Responde ESTRICTAMENTE en texto plano con este formato, sin markdown \
        ni encabezados adicionales:

        Primera línea: el título de la receta.
        Líneas siguientes: los pasos numerados, uno por línea, con el formato "1. ", "2. ", etc.

        No agregues explicaciones fuera de ese formato.
        """
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
