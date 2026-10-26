# Kitchen Calendar

A SwiftUI family dashboard for the kitchen. An iPad acts as the control panel, and a TV shows a large, easy-to-read display.

## Features

- **Calendar**: shows events from your iPad's calendars (EventKit). You can hide calendars you don't want on the TV.
- **Planning mode**: shows this month and next month full screen on the TV.
- **Weather**: current conditions and a 4-day forecast from [Open-Meteo](https://open-meteo.com) (free, no account), based on the iPad's approximate location.
- **To-do and shopping lists**: focus either list full screen on the TV so every item is readable.
- **Dinner**: set tonight's dinner from the iPad.
- **Home controls**: control Apple Home rooms, scenes and lights (including Hue lights added to Apple Home) through HomeKit. This is optional and is switched on in Settings.
- **Seasonal themes**: choose a season or let the app pick one automatically.
- **TV rotation**: supports landscape, or portrait for a TV mounted on its side.

## Requirements

- Xcode (latest recommended)
- An iPad to run the control panel
- A TV or second display connected to the iPad
- Calendar, location and (optionally) Home permissions

## Getting started

1. Clone the repository:
   ```
   git clone https://github.com/GlaksIdeas/Kitchen-Calendar.git
   ```
2. Open `Kitchen Calendar.xcodeproj` in Xcode.
3. Select your development team under Signing & Capabilities.
4. Build and run on your iPad.
5. Grant calendar, location and Home access when prompted.

## Project layout

| File | Purpose |
| --- | --- |
| `KitchenCalendarApp.swift` | App entry point |
| `AppModel.swift` | Shared state and saved settings |
| `ControlPanelView.swift` | iPad control panel |
| `TVDisplayView.swift` | Display shown on the TV |
| `SettingsView.swift` | App settings |
| `CalendarService.swift` | Calendar events |
| `WeatherService.swift` | Weather and location |
| `HomeService.swift` | HomeKit rooms and scenes |
| `LightColorSheet.swift` | Light color picker |
| `DailyContent.swift` | Daily content for the display |
| `Theme.swift` | Colors and seasonal themes |
