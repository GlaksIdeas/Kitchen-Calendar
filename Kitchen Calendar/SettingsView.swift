import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var cal: CalendarService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Screen orientation", selection: $model.tvRotation) {
                        Text("Portrait").tag(90)
                        Text("Portrait (flipped)").tag(270)
                        Text("Landscape").tag(0)
                    }
                    LabeledContent("Status", value: model.tvConnected ? "Connected" : "Not connected")
                } header: {
                    Text("TV")
                } footer: {
                    Text("If the calendar shows upside down on the TV, switch to the flipped option.")
                }

                Section {
                    Toggle("Night mode", isOn: $model.nightEnabled)
                    if model.nightEnabled {
                        Picker("Starts at", selection: $model.nightStart) {
                            ForEach(0..<24, id: \.self) { h in Text(hourLabel(h)).tag(h) }
                        }
                        Picker("Ends at", selection: $model.nightEnd) {
                            ForEach(0..<24, id: \.self) { h in Text(hourLabel(h)).tag(h) }
                        }
                    }
                } header: {
                    Text("Night mode")
                } footer: {
                    Text("Overnight the iPad dims and the TV goes dark, which also eases wear on the iPad’s battery. Tap the iPad to wake both for five minutes.")
                }

                Section("Look") {
                    Picker("Season", selection: $model.season) {
                        Text("Automatic").tag("auto")
                        ForEach(Season.allCases, id: \.self) { s in
                            Text(s.name).tag(s.rawValue)
                        }
                    }
                }

                Section {
                    Toggle("Home controls", isOn: $model.homeEnabled)
                } header: {
                    Text("Lights")
                } footer: {
                    Text("Shows the rooms and scenes from your Home app. Needs the HomeKit capability turned on in Xcode.")
                }

                Section {
                    if !cal.calendarAccess {
                        Text("Allow Calendar access in Settings › Privacy & Security › Calendars.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(cal.calendars) { c in
                        Toggle(isOn: Binding(
                            get: { !model.hiddenCalendars.contains(c.id) },
                            set: { show in
                                if show { model.hiddenCalendars.remove(c.id) } else { model.hiddenCalendars.insert(c.id) }
                            }
                        )) {
                            HStack(spacing: 10) {
                                Circle().fill(c.color).frame(width: 10, height: 10)
                                Text(c.name)
                            }
                        }
                    }
                } header: {
                    Text("Calendars on the TV")
                } footer: {
                    Text("To-dos live in the “\(CalendarService.listName)” list in Reminders, so you can add them from your iPhone too.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func hourLabel(_ h: Int) -> String {
        let hour12 = h % 12 == 0 ? 12 : h % 12
        return "\(hour12) \(h < 12 ? "AM" : "PM")"
    }
}
