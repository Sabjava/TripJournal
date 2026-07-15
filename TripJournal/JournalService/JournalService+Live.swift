import Combine
import Foundation

enum JournalServiceError: LocalizedError {
    case invalidURL
    case unauthorized
    case httpError(statusCode: Int, message: String?)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL is invalid."
        case .unauthorized:
            return "You are not authorized. Please log in again."
        case let .httpError(statusCode, message):
            return message ?? "Request failed with status code \(statusCode)."
        case .decodingError:
            return "Unable to read the server response."
        }
    }
}

/// A live implementation of the `JournalService` that communicates with the Travel Journey API.
final class LiveJournalService: JournalService {
    private static let iso8601Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return formatter
    }()

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    @Published private var token: Token?

    var isAuthenticated: AnyPublisher<Bool, Never> {
        $token
            .map { $0 != nil }
            .eraseToAnyPublisher()
    }

    init(baseURL: URL = URL(string: "http://localhost:8000")!) {
        self.baseURL = baseURL

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            guard let date = Self.iso8601Formatter.date(from: dateString) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid date: \(dateString)"
                )
            }
            return date
        }
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Self.iso8601Formatter.string(from: date))
        }
        self.encoder = encoder
    }

    deinit {
        session.invalidateAndCancel()
    }

    func register(username: String, password: String) async throws -> Token {
        let request = UserCreate(username: username, password: password)
        let token: Token = try await send(
            path: "/register",
            method: "POST",
            body: request,
            requiresAuth: false
        )
        await MainActor.run {
            self.token = token
        }
        return token
    }

    func logIn(username: String, password: String) async throws -> Token {
        let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username
        let encodedPassword = password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? password
        let body = "grant_type=&username=\(encodedUsername)&password=\(encodedPassword)"

        let token: Token = try await send(
            path: "/token",
            method: "POST",
            bodyData: Data(body.utf8),
            contentType: "application/x-www-form-urlencoded",
            requiresAuth: false
        )
        await MainActor.run {
            self.token = token
        }
        return token
    }

    func logOut() {
        token = nil
    }

    func createTrip(with request: TripCreate) async throws -> Trip {
        try await send(path: "/trips", method: "POST", body: request)
    }

    func getTrips() async throws -> [Trip] {
        try await send(path: "/trips", method: "GET")
    }

    func getTrip(withId tripId: Trip.ID) async throws -> Trip {
        try await send(path: "/trips/\(tripId)", method: "GET")
    }

    func updateTrip(withId tripId: Trip.ID, and request: TripUpdate) async throws -> Trip {
        try await send(path: "/trips/\(tripId)", method: "PUT", body: request)
    }

    func deleteTrip(withId tripId: Trip.ID) async throws {
        try await sendVoid(path: "/trips/\(tripId)", method: "DELETE")
    }

    func createEvent(with request: EventCreate) async throws -> Event {
        try await send(path: "/events", method: "POST", body: request)
    }

    func updateEvent(withId eventId: Event.ID, and request: EventUpdate) async throws -> Event {
        try await send(path: "/events/\(eventId)", method: "PUT", body: request)
    }

    func deleteEvent(withId eventId: Event.ID) async throws {
        try await sendVoid(path: "/events/\(eventId)", method: "DELETE")
    }

    func createMedia(with request: MediaCreate) async throws -> Media {
        try await send(path: "/media", method: "POST", body: request)
    }

    func deleteMedia(withId mediaId: Media.ID) async throws {
        try await sendVoid(path: "/media/\(mediaId)", method: "DELETE")
    }

    // MARK: - URLRequest

    /// Creates a configured `URLRequest` for an API endpoint.
    ///
    /// All network calls in this service reuse this helper to set the HTTP method,
    /// request body, content type, accept header, and bearer token when required.
    private func makeURLRequest(
        path: String,
        method: String,
        body: Data? = nil,
        contentType: String? = nil,
        requiresAuth: Bool = true
    ) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw JournalServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        if requiresAuth {
            guard let token else {
                throw JournalServiceError.unauthorized
            }
            request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    // MARK: - Networking

    private func send<Response: Decodable>(
        path: String,
        method: String,
        body: (some Encodable)? = nil,
        requiresAuth: Bool = true
    ) async throws -> Response {
        let bodyData = try body.map { try encoder.encode($0) }
        return try await send(
            path: path,
            method: method,
            bodyData: bodyData,
            contentType: bodyData == nil ? nil : "application/json",
            requiresAuth: requiresAuth
        )
    }

    private func send<Response: Decodable>(
        path: String,
        method: String,
        bodyData: Data? = nil,
        contentType: String? = nil,
        requiresAuth: Bool = true
    ) async throws -> Response {
        let data = try await performRequest(
            path: path,
            method: method,
            bodyData: bodyData,
            contentType: contentType,
            requiresAuth: requiresAuth
        )

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw JournalServiceError.decodingError
        }
    }

    private func sendVoid(
        path: String,
        method: String,
        requiresAuth: Bool = true
    ) async throws {
        _ = try await performRequest(
            path: path,
            method: method,
            bodyData: nil,
            contentType: nil,
            requiresAuth: requiresAuth
        )
    }

    private func performRequest(
        path: String,
        method: String,
        bodyData: Data?,
        contentType: String?,
        requiresAuth: Bool
    ) async throws -> Data {
        let request = try makeURLRequest(
            path: path,
            method: method,
            body: bodyData,
            contentType: contentType,
            requiresAuth: requiresAuth
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JournalServiceError.decodingError
        }

        switch httpResponse.statusCode {
        case 200 ... 299:
            return data
        case 401:
            await MainActor.run {
                self.token = nil
            }
            throw JournalServiceError.unauthorized
        default:
            let message = parseErrorMessage(from: data)
            throw JournalServiceError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    private func parseErrorMessage(from data: Data) -> String? {
        struct APIError: Decodable {
            let detail: String
        }

        if let apiError = try? decoder.decode(APIError.self, from: data) {
            return apiError.detail
        }

        return String(data: data, encoding: .utf8)
    }
}
