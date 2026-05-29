import SwiftUI

struct WeatherSidebarIcon: View {
    var iconSize: CGFloat
    @ObservedObject var appModel: AppModel
    @ObservedObject private var preferencesStore: PreferencesStore
    @Environment(\.sidebarAppearance) private var appearance
    @Environment(\.openSettings) private var openSettings

    private let timer = Timer.publish(every: 600, on: .main, in: .common).autoconnect()

    init(iconSize: CGFloat, appModel: AppModel) {
        self.iconSize = iconSize
        self.appModel = appModel
        self._preferencesStore = ObservedObject(initialValue: appModel.preferencesStore)
    }

    var body: some View {
        VStack(spacing: 1) {
            temperatureText
            weatherIcon
        }
        .frame(width: iconSize + 12, height: iconSize + 12)
        .foregroundStyle(appearance.primaryText.color)
        .background(appearance.widgetBackground.color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(appearance.widgetBorder.color, lineWidth: 1))
        .contentShape(Rectangle())
        .help(helpText)
        .onTapGesture(count: 2) {
            openWeatherSettings()
        }
        .onAppear {
            appModel.refreshWeather()
        }
        .onReceive(timer) { _ in
            appModel.refreshWeather()
        }
        .onReceive(preferencesStore.$preferences) { _ in
            appModel.refreshWeather()
        }
    }

    private var weatherIcon: some View {
        Image(systemName: symbolName)
            .font(.system(size: iconSize * 0.43, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .frame(width: max(18, iconSize * 0.56), height: max(18, iconSize * 0.48))
    }

    private var temperatureText: some View {
        Text(appModel.weatherInfo?.roundedTemperatureText ?? "--°")
            .font(.system(size: max(12, iconSize * 0.32), weight: .semibold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.72)
    }

    private var symbolName: String {
        guard let info = appModel.weatherInfo else {
            return "cloud.sun"
        }

        return WeatherConditionSymbolMapper.symbolName(for: info.weatherCode, isDay: info.isDay)
    }

    private var helpText: String {
        if let info = appModel.weatherInfo {
            return info.accessibilityDescription
        }

        if let error = appModel.weatherErrorDescription {
            return error
        }

        return "Set a weather location in Settings"
    }

    private func openWeatherSettings() {
        openSettings()
        appModel.requestWidgetSettings(.weather)
        appModel.bringSettingsWindowToFront()

        DispatchQueue.main.async {
            appModel.requestWidgetSettings(.weather)
            appModel.bringSettingsWindowToFront()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            appModel.requestWidgetSettings(.weather)
            appModel.bringSettingsWindowToFront()
        }
    }
}
