# OpenDock Widgets

Widgets are in-repo, compiled Swift features with a small JSON manifest. The
manifest describes discovery, ordering, sizing, defaults, and settings. Swift
owns the UI, actions, popovers, and service logic.

## Folder Layout

```text
Sources/OpenDock/
  Resources/Widgets/<widget-id>/widget.json
  Widgets/<WidgetName>/<WidgetName>Widget.swift
```

Each built-in widget needs:

- one `widget.json` manifest;
- one `WidgetDefinition` Swift type;
- optional view or service files;
- one registration entry in `WidgetRegistry.builtinDefinitions`.

## Manifest

```json
{
  "id": "weather",
  "title": "Weather",
  "description": "Show current conditions.",
  "systemImage": "cloud.sun",
  "defaultEnabled": true,
  "placement": "final",
  "order": 35,
  "dockSize": {
    "vertical": { "type": "square" },
    "horizontal": { "type": "square" }
  },
  "settings": [
    {
      "id": "location",
      "type": "string",
      "title": "Location",
      "description": "City or location name.",
      "defaultValue": ""
    }
  ]
}
```

Use a stable lowercase `id`. Existing user preferences and sidebar items persist
that value.

`placement` currently supports `final`, which means the widget is fixed at the
end of the dock. `order` controls the final-widget order. Lower numbers appear
first.

`dockSize` supports:

- `square`: standard dock cell, `iconSize + 12`.
- `expanded`: wider inline widget; set `minimumLength` and optionally
  `iconMultiplier`.

Settings support `boolean`, `string`, `integer`, and `number`. Boolean and
string settings render automatically as options nested under their widget in
Settings.

## Add Weather

1. Add `Sources/OpenDock/Resources/Widgets/weather/widget.json`.
2. Add `Sources/OpenDock/Widgets/Weather/WeatherWidget.swift`.
3. Implement `WidgetDefinition`:

```swift
import SwiftUI

struct WeatherWidgetDefinition: WidgetDefinition {
    let manifest = WidgetManifestLoader.requireBundledManifest(id: "weather")

    @MainActor
    func makeDockView(context: WidgetContext) -> AnyView {
        AnyView(
            SidebarIconButtonLabel(
                icon: .openDockSymbol(manifest.systemImage),
                iconSize: context.iconSize
            )
        )
    }

    @MainActor
    func performPrimaryAction(context: WidgetContext) {
        // Open a popover, refresh weather, or launch a details surface.
    }
}
```

4. Register it in `WidgetRegistry.builtinDefinitions`:

```swift
WeatherWidgetDefinition(),
```

5. Read settings through `context.appModel.preferencesStore.preferences`:

```swift
let location = context.appModel.preferencesStore.preferences.widgetPreferences
    .stringSetting("location", for: "weather", default: "")
```

6. Add focused tests for manifest decoding, registry order, default injection,
   visibility, sizing, and any weather service behavior.

## Compatibility

OpenDock still decodes old `SidebarItem.systemKind` values and old widget
preference keys. New code should use `widgetID`, `WidgetRegistry`, and
`WidgetPreferences`.
