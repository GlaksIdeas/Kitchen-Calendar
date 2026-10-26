import Combine
import SwiftUI
import UIKit

enum FocusedList {
    case todo, shopping

    var title: String { self == .todo ? "To do" : "Shopping" }
    var symbol: String { self == .todo ? "checklist" : "cart" }
}

/// Shared state for both screens. Settings are saved on the iPad.
@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    let calendar = CalendarService()
    let weather = WeatherService()
    let home = HomeService()

    @Published var now = Date()
    @Published var tvConnected = false
    /// When on, the TV shows this month and next month full screen for planning.
    @Published var planningMode = false {
        didSet { if planningMode { focusedList = nil } }
    }
    /// When set, the TV shows that list full screen so every item is readable.
    @Published var focusedList: FocusedList? {
        didSet { if focusedList != nil { planningMode = false } }
    }

    @Published var dinner: String {
        didSet { UserDefaults.standard.set(dinner, forKey: Keys.dinner) }
    }
    /// 90 or 270 for a TV hung in portrait, 0 for landscape.
    @Published var tvRotation: Int {
        didSet { UserDefaults.standard.set(tvRotation, forKey: Keys.rotation) }
    }
    /// "auto" or a season's raw value.
    @Published var season: String {
        didSet { UserDefaults.standard.set(season, forKey: Keys.season) }
    }
    @Published var homeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(homeEnabled, forKey: Keys.home)
            if homeEnabled { home.start() }
        }
    }
    /// Calendars the person has chosen not to show on the TV.
    @Published var hiddenCalendars: Set<String> {
        didSet { UserDefaults.standard.set(Array(hiddenCalendars), forKey: Keys.hidden) }
    }

    // MARK: Night mode: dims the iPad and darkens the TV overnight.

    @Published var nightEnabled: Bool {
        didSet { UserDefaults.standard.set(nightEnabled, forKey: Keys.night); refreshNight() }
    }
    /// Hour of the day (0–23) night mode starts and ends.
    @Published var nightStart: Int {
        didSet { UserDefaults.standard.set(nightStart, forKey: Keys.nightStart); refreshNight() }
    }
    @Published var nightEnd: Int {
        didSet { UserDefaults.standard.set(nightEnd, forKey: Keys.nightEnd); refreshNight() }
    }
    @Published private(set) var isNight = false

    // MARK: Idle screensaver: after a minute without a touch the iPad dims and shows a screensaver.

    @Published private(set) var isIdle = false

    private static let idleTimeout: TimeInterval = 60
    private var lastTouch = Date()
    private var idleTicker: Timer?

    private var wakeUntil: Date?
    private var dayBrightness: CGFloat = 0.6
    private var isDimmed = false

    private enum Keys {
        static let dinner = "dinner", rotation = "tvRotation", season = "season"
        static let home = "homeEnabled", hidden = "hiddenCalendars"
        static let night = "nightEnabled", nightStart = "nightStart", nightEnd = "nightEnd"
    }

    private var ticker: Timer?

    private init() {
        let d = UserDefaults.standard
        dinner = d.string(forKey: Keys.dinner) ?? ""
        tvRotation = d.object(forKey: Keys.rotation) as? Int ?? 90
        season = d.string(forKey: Keys.season) ?? "auto"
        homeEnabled = d.bool(forKey: Keys.home)
        hiddenCalendars = Set(d.stringArray(forKey: Keys.hidden) ?? [])
        nightEnabled = d.object(forKey: Keys.night) as? Bool ?? true
        nightStart = d.object(forKey: Keys.nightStart) as? Int ?? 23
        nightEnd = d.object(forKey: Keys.nightEnd) as? Int ?? 6
    }

    func start() async {
        UIApplication.shared.isIdleTimerDisabled = true   // keep the iPad awake
        ticker = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.now = Date()
                self?.refreshNight()
            }
        }
        idleTicker = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshIdle() }
        }
        refreshNight()
        weather.start()
        if homeEnabled { home.start() }
        await calendar.start()
    }

    /// The iPad's own screen (not the TV).
    private var iPadScreen: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.session.role == .windowApplication }?
            .screen
    }

    /// Switches night mode on or off based on the time, the settings, and any tap to wake.
    func refreshNight() {
        let hour = Calendar.current.component(.hour, from: Date())
        let inWindow: Bool
        if nightStart == nightEnd {
            inWindow = false
        } else if nightStart < nightEnd {
            inWindow = hour >= nightStart && hour < nightEnd
        } else {
            inWindow = hour >= nightStart || hour < nightEnd   // crosses midnight
        }
        let awake = (wakeUntil ?? .distantPast) > Date()
        let night = nightEnabled && inWindow && !awake
        guard night != isNight else { return }
        isNight = night
        updateBrightness()
    }

    /// Any touch on the iPad counts as activity; it wakes the screensaver.
    func noteActivity() {
        lastTouch = Date()
        if isIdle { refreshIdle() }
    }

    private func refreshIdle() {
        let idle = Date().timeIntervalSince(lastTouch) >= Self.idleTimeout
        guard idle != isIdle else { return }
        isIdle = idle
        updateBrightness()
    }

    /// Dims the iPad while night mode or the screensaver is showing, and restores it afterwards.
    private func updateBrightness() {
        guard let screen = iPadScreen else { return }
        if isNight || isIdle {
            if !isDimmed {
                dayBrightness = screen.brightness
                isDimmed = true
            }
            screen.brightness = isNight ? 0.02 : 0.08
        } else if isDimmed {
            isDimmed = false
            screen.brightness = dayBrightness
        }
    }

    /// A tap during the night brings everything back for five minutes, with the iPad at full brightness.
    func wakeBriefly() {
        wakeUntil = Date().addingTimeInterval(5 * 60)
        lastTouch = Date()
        dayBrightness = 1.0   // so leaving the dimmed state restores to full
        isIdle = false
        refreshNight()
        updateBrightness()
        if !isDimmed { iPadScreen?.brightness = 1.0 }
    }

    var theme: Theme {
        (Season(rawValue: season) ?? Season.current(now)).theme
    }

    /// Events on a given day from the calendars that are switched on.
    func events(on day: Date) -> [CalEvent] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        return calendar.events
            .filter { e in
                !hiddenCalendars.contains(e.calendarID) &&
                (e.isAllDay ? (e.start < end && e.end > start) : (e.start >= start && e.start < end))
            }
            .sorted { a, b in
                if a.isAllDay != b.isAllDay { return a.isAllDay }
                return a.start < b.start
            }
    }

    /// Calendars to show in the legend: switched on and with something on them.
    var legendCalendars: [CalInfo] {
        let used = Set(calendar.events.map(\.calendarID))
        return calendar.calendars.filter { used.contains($0.id) && !hiddenCalendars.contains($0.id) }
    }
}
