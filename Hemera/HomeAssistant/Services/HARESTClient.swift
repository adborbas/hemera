import Foundation
import HemeraLog

/// Errors from the Home Assistant REST API.
enum HARESTError: Error {
    case badResponse(URLResponse)
    case decodingError(Error)
}

/// Abstraction for Home Assistant REST API operations.
protocol HARESTClienting: Sendable {
    func fetchVersion() async -> String?
    func fetchAreaMappings() async throws -> [AreaMapping]
}

/// Client for Home Assistant REST API calls.
///
/// Used for operations that aren't available via WebSocket,
/// such as template rendering for area mappings.
actor HARESTClient: HARESTClienting {
    private let urlProvider: @Sendable () -> URL
    private let tokenProvider: @Sendable () async throws -> String

    init(
        urlProvider: @escaping @Sendable () -> URL,
        tokenProvider: @escaping @Sendable () async throws -> String
    ) {
        self.urlProvider = urlProvider
        self.tokenProvider = tokenProvider
    }

    /// Renders a Jinja2 template via the Home Assistant REST API.
    ///
    /// - Parameter template: The Jinja2 template string
    /// - Returns: The rendered template result as a string
    func renderTemplate(_ template: String) async throws -> String {
        let token = try await tokenProvider()
        var request = URLRequest(url: urlProvider().appendingPathComponent("/api/template"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        struct TemplateBody: Encodable { let template: String }
        request.httpBody = try JSONEncoder().encode(TemplateBody(template: template))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            Log.error("REST template request failed with HTTP \(statusCode)")
            throw HARESTError.badResponse(response)
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Fetches the Home Assistant server version.
    func fetchVersion() async -> String? {
        do {
            let token = try await tokenProvider()
            var request = URLRequest(url: urlProvider().appendingPathComponent("/api/config"))
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }

            struct HAConfig: Decodable { let version: String }
            return try? JSONDecoder().decode(HAConfig.self, from: data).version
        } catch {
            Log.warning("Failed to fetch HA version", cause: error)
            return nil
        }
    }

    /// Fetches area mappings using a Jinja2 template.
    ///
    /// Returns area IDs, names, and their associated entity IDs.
    func fetchAreaMappings() async throws -> [AreaMapping] {
        let template = """
        {% set ns = namespace(out=[]) %}

        {% for area_id in areas() %}
          {% set name = area_name(area_id) %}
          {% set entity_ids = area_entities(area_id) %}
          {% set ns.out = ns.out + [ {
            "area_id": area_id,
            "area_name": name,
            "entities": entity_ids
          } ] %}
        {% endfor %}

        {{ ns.out | to_json }}
        """

        let rendered = try await renderTemplate(template)
        guard let jsonData = rendered.data(using: .utf8) else { return [] }

        do {
            return try JSONDecoder().decode([AreaMapping].self, from: jsonData)
        } catch {
            throw HARESTError.decodingError(error)
        }
    }
}

/// Represents an area with its entities from Home Assistant.
struct AreaMapping: Decodable, Sendable {
    let area_id: String
    let area_name: String
    let entities: [String]
}
