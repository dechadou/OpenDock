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
  "order": 25,
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
    },
    {
      "id": "temperatureUnit",
      "type": "choice",
      "title": "Temperature",
      "description": "Choose how weather temperatures are shown.",
      "defaultValue": "celsius",
      "options": [
        { "id": "celsius", "title": "Celsius" },
        { "id": "fahrenheit", "title": "Fahrenheit" }
      ]
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

Settings support `boolean`, `string`, `integer`, `number`, and `choice`. Boolean and
string settings render automatically as options nested under their widget in
Settings. `choice` settings render as segmented pickers and use string values
from their `options` list.

## Built-in Weather

Weather uses Open-Meteo and needs no API key. Its manifest stores two settings:
`location` and `temperatureUnit`. The dock view stays square and centered, with
the temperature on top and the weather symbol below. The location field searches
Open-Meteo geocoding suggestions after the user types at least two characters, so
the saved value can use the provider's normalized city, region, and country text.

## Built-in Volume

Volume uses CoreAudio/AudioToolbox against the default output device. The dock
view is only a speaker icon; clicking it opens a vertical popover with the
slider and mute button. Devices that do not expose software volume or mute render
disabled controls.

## Compatibility

OpenDock still decodes old `SidebarItem.systemKind` values and old widget
preference keys. New code should use `widgetID`, `WidgetRegistry`, and
`WidgetPreferences`.
