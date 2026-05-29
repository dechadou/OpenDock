import Foundation

public enum WeatherServiceError: Error, Equatable, CustomStringConvertible {
    case emptyLocation
    case invalidURL
    case locationNotFound(String)
    case invalidResponse

    public var description: String {
        switch self {
        case .emptyLocation:
            return "Weather location is empty."
        case .invalidURL:
            return "Could not build the weather request URL."
        case .locationNotFound(let location):
            return "Could not find weather for \(location)."
        case .invalidResponse:
            return "Weather service returned an invalid response."
        }
    }
}

public actor WeatherService {
    public static let shared = WeatherService()

    private struct CacheKey: Hashable {
        var location: String
        var unit: WeatherTemperatureUnit
    }

    private struct CachedWeather {
        var info: WeatherInfo
        var date: Date
    }

    private var cache: [CacheKey: CachedWeather] = [:]
    private let cacheDuration: TimeInterval

    public init(cacheDuration: TimeInterval = 600) {
        self.cacheDuration = cacheDuration
    }

    public func currentWeather(location rawLocation: String, unit: WeatherTemperatureUnit) async throws -> WeatherInfo {
        let locationQuery = rawLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !locationQuery.isEmpty else {
            throw WeatherServiceError.emptyLocation
        }

        let key = CacheKey(location: locationQuery.lowercased(), unit: unit)
        if let cached = cache[key], Date().timeIntervalSince(cached.date) < cacheDuration {
            return cached.info
        }

        guard let geocodingURL = Self.geocodingURL(for: locationQuery) else {
            throw WeatherServiceError.invalidURL
        }

        let (geocodingData, _) = try await URLSession.shared.data(from: geocodingURL)
        let location = try Self.decodeLocation(from: geocodingData, query: locationQuery)

        guard let forecastURL = Self.forecastURL(latitude: location.latitude, longitude: location.longitude, unit: unit) else {
            throw WeatherServiceError.invalidURL
        }

        let (forecastData, _) = try await URLSession.shared.data(from: forecastURL)
        let info = try Self.decodeWeatherInfo(from: forecastData, location: location, unit: unit)
        cache[key] = CachedWeather(info: info, date: Date())
        return info
    }

    public func searchLocations(matching rawQuery: String, count: Int = 5) async throws -> [WeatherLocation] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return []
        }

        guard let url = Self.geocodingURL(for: query, count: count) else {
            throw WeatherServiceError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        return try Self.decodeLocations(from: data)
    }

    public static func geocodingURL(for location: String, count: Int = 1) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "geocoding-api.open-meteo.com"
        components.path = "/v1/search"
        components.queryItems = [
            URLQueryItem(name: "name", value: location),
            URLQueryItem(name: "count", value: "\(max(1, count))"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json"),
        ]
        return components.url
    }

    public static func forecastURL(latitude: Double, longitude: Double, unit: WeatherTemperatureUnit) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.open-meteo.com"
        components.path = "/v1/forecast"
        components.queryItems = [
            URLQueryItem(name: "latitude", value: "\(latitude)"),
            URLQueryItem(name: "longitude", value: "\(longitude)"),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "temperature_unit", value: unit.apiValue),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        return components.url
    }

    public static func decodeLocation(from data: Data, query: String = "") throws -> WeatherLocation {
        guard let location = try decodeLocations(from: data).first else {
            throw WeatherServiceError.locationNotFound(query)
        }
        return location
    }

    public static func decodeLocations(from data: Data) throws -> [WeatherLocation] {
        let response = try JSONDecoder().decode(GeocodingResponse.self, from: data)
        return response.results ?? []
    }

    public static func decodeWeatherInfo(
        from data: Data,
        location: WeatherLocation,
        unit: WeatherTemperatureUnit,
        observedAt: Date = Date()
    ) throws -> WeatherInfo {
        let response = try JSONDecoder().decode(ForecastResponse.self, from: data)
        guard let current = response.current else {
            throw WeatherServiceError.invalidResponse
        }

        return WeatherInfo(
            location: location,
            temperature: current.temperature,
            unit: unit,
            weatherCode: current.weatherCode,
            isDay: current.isDay == 1,
            observedAt: observedAt
        )
    }
}

private struct GeocodingResponse: Decodable {
    var results: [WeatherLocation]?
}

private struct ForecastResponse: Decodable {
    var current: CurrentWeather?
}

private struct CurrentWeather: Decodable {
    var temperature: Double
    var weatherCode: Int
    var isDay: Int

    private enum CodingKeys: String, CodingKey {
        case temperature = "temperature_2m"
        case weatherCode = "weather_code"
        case isDay = "is_day"
    }
}
