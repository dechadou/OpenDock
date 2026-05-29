import CoreGraphics
import Foundation
import SwiftUI

public struct WidgetID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var description: String {
        rawValue
    }
}

public extension WidgetID {
    static let windows = WidgetID("windows")
    static let trash = WidgetID("trash")
    static let dateTime = WidgetID("date-time")
    static let weather = WidgetID("weather")
    static let media = WidgetID("media")
    static let volume = WidgetID("volume")
}

public enum WidgetSettingIDs {
    public static let hideMediaSourceAppIcon = "hideSourceAppIcon"
    public static let weatherLocation = "location"
    public static let weatherTemperatureUnit = "temperatureUnit"
}

public enum WidgetPlacement: String, Codable, Sendable {
    case final
}

public enum WidgetDockSizeType: String, Codable, Sendable {
    case square
    case expanded
}

public struct WidgetDockAxisSize: Codable, Equatable, Sendable {
    public var type: WidgetDockSizeType
    public var minimumLength: Double?
    public var iconMultiplier: Double?

    public init(type: WidgetDockSizeType, minimumLength: Double? = nil, iconMultiplier: Double? = nil) {
        self.type = type
        self.minimumLength = minimumLength
        self.iconMultiplier = iconMultiplier
    }

    public func length(iconSize: CGFloat) -> CGFloat {
        switch type {
        case .square:
            return iconSize + 12
        case .expanded:
            let minimum = CGFloat(minimumLength ?? Double(iconSize + 12))
            let scaled = iconMultiplier.map { iconSize * CGFloat($0) } ?? 0
            return max(minimum, scaled)
        }
    }
}

public struct WidgetDockSizing: Codable, Equatable, Sendable {
    public var vertical: WidgetDockAxisSize
    public var horizontal: WidgetDockAxisSize

    public init(vertical: WidgetDockAxisSize, horizontal: WidgetDockAxisSize) {
        self.vertical = vertical
        self.horizontal = horizontal
    }

    public func length(edge: SidebarEdge, iconSize: CGFloat) -> CGFloat {
        edge.isVertical ? vertical.length(iconSize: iconSize) : horizontal.length(iconSize: iconSize)
    }
}

public enum WidgetSettingType: String, Codable, Sendable {
    case boolean
    case string
    case integer
    case number
    case choice
}

public struct WidgetSettingOption: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public enum WidgetSettingValue: Codable, Equatable, Sendable {
    case bool(Bool)
    case string(String)
    case integer(Int)
    case number(Double)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }

        if let value = try? container.decode(Int.self) {
            self = .integer(value)
            return
        }

        if let value = try? container.decode(Double.self) {
            self = .number(value)
            return
        }

        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }

        throw DecodingError.typeMismatch(
            WidgetSettingValue.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported widget setting value")
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .bool(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        }
    }

    public var boolValue: Bool? {
        guard case .bool(let value) = self else {
            return nil
        }

        return value
    }

    public var stringValue: String? {
        guard case .string(let value) = self else {
            return nil
        }

        return value
    }
}

public struct WidgetSettingDefinition: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var type: WidgetSettingType
    public var title: String
    public var detail: String?
    public var defaultValue: WidgetSettingValue
    public var options: [WidgetSettingOption]

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case detail = "description"
        case defaultValue
        case options
    }

    public init(
        id: String,
        type: WidgetSettingType,
        title: String,
        detail: String? = nil,
        defaultValue: WidgetSettingValue,
        options: [WidgetSettingOption] = []
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.detail = detail
        self.defaultValue = defaultValue
        self.options = options
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(WidgetSettingType.self, forKey: .type)
        self.title = try container.decode(String.self, forKey: .title)
        self.detail = try container.decodeIfPresent(String.self, forKey: .detail)
        self.defaultValue = try container.decode(WidgetSettingValue.self, forKey: .defaultValue)
        self.options = try container.decodeIfPresent([WidgetSettingOption].self, forKey: .options) ?? []
    }
}

public struct WidgetManifest: Codable, Equatable, Identifiable, Sendable {
    public var id: WidgetID
    public var title: String
    public var description: String
    public var systemImage: String
    public var defaultEnabled: Bool
    public var placement: WidgetPlacement
    public var order: Int
    public var dockSize: WidgetDockSizing
    public var settings: [WidgetSettingDefinition]

    public init(
        id: WidgetID,
        title: String,
        description: String,
        systemImage: String,
        defaultEnabled: Bool,
        placement: WidgetPlacement,
        order: Int,
        dockSize: WidgetDockSizing,
        settings: [WidgetSettingDefinition] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.systemImage = systemImage
        self.defaultEnabled = defaultEnabled
        self.placement = placement
        self.order = order
        self.dockSize = dockSize
        self.settings = settings
    }
}

public struct WidgetPreferences: Codable, Equatable, Sendable {
    public var enabledByID: [WidgetID: Bool]
    public var settingsByWidgetID: [WidgetID: [String: WidgetSettingValue]]

    private enum CodingKeys: String, CodingKey {
        case enabledByID
        case settingsByWidgetID
    }

    public init(enabledByID: [WidgetID: Bool] = [:], settingsByWidgetID: [WidgetID: [String: WidgetSettingValue]] = [:]) {
        self.enabledByID = enabledByID
        self.settingsByWidgetID = settingsByWidgetID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.enabledByID = try Self.decodeEnabledByID(from: container)
        self.settingsByWidgetID = try Self.decodeSettingsByWidgetID(from: container)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try Self.encode(enabledByID, into: &container)
        try Self.encode(settingsByWidgetID, into: &container)
    }

    public static func defaults(registry: WidgetRegistry = .shared) -> WidgetPreferences {
        WidgetPreferences().fillingDefaults(from: registry)
    }

    public func fillingDefaults(from registry: WidgetRegistry = .shared) -> WidgetPreferences {
        var copy = self

        for manifest in registry.manifests {
            if copy.enabledByID[manifest.id] == nil {
                copy.enabledByID[manifest.id] = manifest.defaultEnabled
            }

            for setting in manifest.settings
            where copy.settingsByWidgetID[manifest.id]?[setting.id] == nil {
                copy.settingsByWidgetID[manifest.id, default: [:]][setting.id] = setting.defaultValue
            }
        }

        return copy
    }

    public func isEnabled(_ widgetID: WidgetID, default defaultValue: Bool = true) -> Bool {
        enabledByID[widgetID] ?? defaultValue
    }

    public mutating func setEnabled(_ isEnabled: Bool, for widgetID: WidgetID) {
        enabledByID[widgetID] = isEnabled
    }

    public func settingValue(_ settingID: String, for widgetID: WidgetID, default defaultValue: WidgetSettingValue) -> WidgetSettingValue {
        settingsByWidgetID[widgetID]?[settingID] ?? defaultValue
    }

    public mutating func setSetting(_ value: WidgetSettingValue, for widgetID: WidgetID, settingID: String) {
        settingsByWidgetID[widgetID, default: [:]][settingID] = value
    }

    public func boolSetting(_ settingID: String, for widgetID: WidgetID, default defaultValue: Bool) -> Bool {
        settingValue(settingID, for: widgetID, default: .bool(defaultValue)).boolValue ?? defaultValue
    }

    public func stringSetting(_ settingID: String, for widgetID: WidgetID, default defaultValue: String) -> String {
        settingValue(settingID, for: widgetID, default: .string(defaultValue)).stringValue ?? defaultValue
    }

    private static func decodeEnabledByID(from container: KeyedDecodingContainer<CodingKeys>) throws -> [WidgetID: Bool] {
        guard container.contains(.enabledByID) else {
            return [:]
        }

        let keyed = try container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .enabledByID)
        var values: [WidgetID: Bool] = [:]

        for key in keyed.allKeys {
            values[WidgetID(key.stringValue)] = try keyed.decode(Bool.self, forKey: key)
        }

        return values
    }

    private static func decodeSettingsByWidgetID(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> [WidgetID: [String: WidgetSettingValue]] {
        guard container.contains(.settingsByWidgetID) else {
            return [:]
        }

        let widgets = try container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .settingsByWidgetID)
        var values: [WidgetID: [String: WidgetSettingValue]] = [:]

        for widgetKey in widgets.allKeys {
            let settings = try widgets.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: widgetKey)
            var settingValues: [String: WidgetSettingValue] = [:]

            for settingKey in settings.allKeys {
                settingValues[settingKey.stringValue] = try settings.decode(WidgetSettingValue.self, forKey: settingKey)
            }

            values[WidgetID(widgetKey.stringValue)] = settingValues
        }

        return values
    }

    private static func encode(
        _ values: [WidgetID: Bool],
        into container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        var keyed = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .enabledByID)

        for key in values.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            if let value = values[key] {
                try keyed.encode(value, forKey: DynamicCodingKey(key.rawValue))
            }
        }
    }

    private static func encode(
        _ values: [WidgetID: [String: WidgetSettingValue]],
        into container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        var widgets = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .settingsByWidgetID)

        for widgetID in values.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            var settings = widgets.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: DynamicCodingKey(widgetID.rawValue))

            for settingID in (values[widgetID] ?? [:]).keys.sorted() {
                if let value = values[widgetID]?[settingID] {
                    try settings.encode(value, forKey: DynamicCodingKey(settingID))
                }
            }
        }
    }
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

public struct WidgetContext {
    public var item: SidebarItem
    public var appModel: AppModel
    public var iconSize: CGFloat
    public var edge: SidebarEdge
    public var presentCalendar: () -> Void

    public init(
        item: SidebarItem,
        appModel: AppModel,
        iconSize: CGFloat,
        edge: SidebarEdge,
        presentCalendar: @escaping () -> Void = {}
    ) {
        self.item = item
        self.appModel = appModel
        self.iconSize = iconSize
        self.edge = edge
        self.presentCalendar = presentCalendar
    }
}

public protocol WidgetDefinition: Sendable {
    var manifest: WidgetManifest { get }
    var usesCustomDockInteraction: Bool { get }

    @MainActor
    func makeDockView(context: WidgetContext) -> AnyView

    @MainActor
    func makeContextMenu(context: WidgetContext) -> AnyView

    @MainActor
    func performPrimaryAction(context: WidgetContext)
}

public extension WidgetDefinition {
    var usesCustomDockInteraction: Bool {
        false
    }

    @MainActor
    func makeContextMenu(context _: WidgetContext) -> AnyView {
        AnyView(EmptyView())
    }

    @MainActor
    func performPrimaryAction(context _: WidgetContext) {}
}

public enum WidgetManifestLoader {
    public enum LoaderError: Error, Equatable {
        case missingManifest(WidgetID)
    }

    public static func bundledManifest(id: WidgetID) throws -> WidgetManifest {
        try bundledManifest(id: id, bundle: defaultResourceBundle)
    }

    public static func bundledManifest(id: WidgetID, bundle: Bundle) throws -> WidgetManifest {
        guard
            let url = bundle.url(
                forResource: "widget",
                withExtension: "json",
                subdirectory: "Widgets/\(id.rawValue)"
            )
        else {
            throw LoaderError.missingManifest(id)
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WidgetManifest.self, from: data)
    }

    private static var defaultResourceBundle: Bundle {
        let bundleName = "OpenDock_OpenDockCore.bundle"
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent(bundleName),
            Bundle.main.bundleURL.appendingPathComponent(bundleName),
            Bundle.module.bundleURL,
        ]

        return candidates.compactMap { $0 }.compactMap(Bundle.init(url:)).first ?? .module
    }

    public static func requireBundledManifest(id: WidgetID) -> WidgetManifest {
        do {
            return try bundledManifest(id: id)
        } catch {
            preconditionFailure("Missing or invalid widget manifest for \(id.rawValue): \(error)")
        }
    }
}

public struct WidgetRegistry: Sendable {
    public enum ValidationError: Error, Equatable, CustomStringConvertible {
        case duplicateID(WidgetID)

        public var description: String {
            switch self {
            case .duplicateID(let id):
                return "Duplicate widget id: \(id.rawValue)"
            }
        }
    }

    public static var builtinDefinitions: [any WidgetDefinition] {
        [
            WindowsWidgetDefinition(),
            DateTimeWidgetDefinition(),
            WeatherWidgetDefinition(),
            MediaWidgetDefinition(),
            VolumeWidgetDefinition(),
            TrashWidgetDefinition(),
        ]
    }

    public static let shared: WidgetRegistry = {
        do {
            return try WidgetRegistry(definitions: builtinDefinitions)
        } catch {
            preconditionFailure("Invalid built-in widget registry: \(error)")
        }
    }()

    public let manifests: [WidgetManifest]
    private let definitionsByID: [WidgetID: any WidgetDefinition]

    public init(definitions: [any WidgetDefinition]) throws {
        var definitionsByID: [WidgetID: any WidgetDefinition] = [:]
        var manifests: [WidgetManifest] = []

        for definition in definitions {
            let id = definition.manifest.id
            guard definitionsByID[id] == nil else {
                throw ValidationError.duplicateID(id)
            }

            definitionsByID[id] = definition
            manifests.append(definition.manifest)
        }

        self.definitionsByID = definitionsByID
        self.manifests = manifests.sorted {
            if $0.order == $1.order {
                return $0.id.rawValue < $1.id.rawValue
            }

            return $0.order < $1.order
        }
    }

    public func definition(for widgetID: WidgetID) -> (any WidgetDefinition)? {
        definitionsByID[widgetID]
    }

    public func manifest(for widgetID: WidgetID) -> WidgetManifest? {
        definitionsByID[widgetID]?.manifest
    }

    public func manifests(placement: WidgetPlacement) -> [WidgetManifest] {
        manifests.filter { $0.placement == placement }
    }

    public var defaultManifests: [WidgetManifest] {
        manifests.filter(\.defaultEnabled)
    }
}
