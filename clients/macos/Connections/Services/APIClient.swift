import Foundation

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct ServerError: Codable {
    let error: String
}

@Observable
final class APIClient {
    var serverURL: String {
        didSet {
            let trimmed = serverURL.hasSuffix("/")
                ? String(serverURL.dropLast())
                : serverURL
            UserDefaults.standard.set(trimmed, forKey: "serverURL")
        }
    }

    static let shared = APIClient()

    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    private init() {
        self.serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:8080"
    }

    private var baseURL: URL {
        URL(string: serverURL)!
    }

    // MARK: - Generic HTTP Methods

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        let url = buildURL(path: path, query: query)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return try await perform(request)
    }

    func post<T: Decodable>(_ path: String, body: (some Encodable)? = nil as Empty?) async throws -> T {
        let url = buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try encoder.encode(body)
        }
        return try await perform(request)
    }

    func postRaw<T: Decodable>(_ path: String, body: Data, contentType: String) async throws -> T {
        let url = buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return try await perform(request)
    }

    func postNoBody<T: Decodable>(_ path: String) async throws -> T {
        let url = buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await perform(request)
    }

    func put<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        let url = buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await perform(request)
    }

    func patch<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        let url = buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await perform(request)
    }

    func delete(_ path: String) async throws {
        let url = buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError(message: "Invalid response")
        }
        if http.statusCode >= 400 {
            throw extractError(from: data, statusCode: http.statusCode)
        }
    }

    func postVoid(_ path: String) async throws {
        let url = buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError(message: "Invalid response")
        }
        if http.statusCode >= 400 {
            throw extractError(from: data, statusCode: http.statusCode)
        }
    }

    // MARK: - Health Check

    func healthCheck() async -> Bool {
        do {
            let _: [String: String] = try await get("/health")
            return true
        } catch {
            return false
        }
    }

    // MARK: - Private

    private func buildURL(path: String, query: [String: String] = [:]) -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return components.url!
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError(message: "Invalid response")
        }
        if http.statusCode >= 400 {
            throw extractError(from: data, statusCode: http.statusCode)
        }
        return try decoder.decode(T.self, from: data)
    }

    private func extractError(from data: Data, statusCode: Int) -> APIError {
        if let serverError = try? decoder.decode(ServerError.self, from: data) {
            return APIError(message: serverError.error)
        }
        return APIError(message: "HTTP \(statusCode)")
    }
}

// Used as a placeholder for optional post bodies
private struct Empty: Encodable {}
