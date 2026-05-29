import Foundation

public enum WeatherTemperatureUnit: String, Codable, CaseIterable, Sendable {
    case celsius
    case fahrenheit

    public var apiValue: String {
        rawValue
    }

    public var symbol: String {
        switch self {
        case .celsius:
            return "C"
        case .fahrenheit:
            return "F"
        }
    }
}

public struct WeatherLocation: Codable, Equatable, Identifiable, Sendable {
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var country: String?
    public var admin1: String?

    public var id: String {
        "\(name)|\(latitude)|\(longitude)"
    }

    public init(name: String, latitude: Double, longitude: Double, country: String? = nil, admin1: String? = nil) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.country = country
        self.admin1 = admin1
    }

    public var displayName: String {
        [name, admin1, country]
            .compactMap { value in
                guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                    !trimmed.isEmpty
                else {
                    return nil
                }
                return trimmed.isEmpty ? nil : trimmed
            }
            .joined(separator: ", ")
    }
}

public struct WeatherInfo: Equatable, Sendable {
    public var location: WeatherLocation
    public var temperature: Double
    public var unit: WeatherTemperatureUnit
    public var weatherCode: Int
    public var isDay: Bool
    public var observedAt: Date

    public init(
        location: WeatherLocation,
        temperature: Double,
        unit: WeatherTemperatureUnit,
        weatherCode: Int,
        isDay: Bool,
        observedAt: Date
    ) {
        self.location = location
        self.temperature = temperature
        self.unit = unit
        self.weatherCode = weatherCode
        self.isDay = isDay
        self.observedAt = observedAt
    }

    public var roundedTemperatureText: String {
        "\(Int(temperature.rounded()))°"
    }

    public var accessibilityDescription: String {
        "\(location.displayName), \(roundedTemperatureText)\(unit.symbol)"
    }
}

public enum WeatherConditionSymbolMapper {
    public static func symbolName(for weatherCode: Int, isDay: Bool) -> String {
        switch weatherCode {
        case 0:
            return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2:
            return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3:
            return "cloud.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51, 53, 55, 56, 57:
            return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67, 80, 81, 82:
            return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86:
            return "cloud.snow.fill"
        case 95, 96, 99:
            return "cloud.bolt.rain.fill"
        default:
            return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        }
    }
}
