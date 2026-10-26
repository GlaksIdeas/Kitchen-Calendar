import Combine
import EventKit
import SwiftUI

struct CalEvent: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let color: Color
    let calendarID: String
}

struct CalInfo: Identifiable {
    let id: String
    let name: String
    let color: Color
}

struct TodoItem: Identifiable {
    let id: String
    let title: String
    let done: Bool
}

/// Reads your calendars and the "Kitchen" Reminders list straight from the iPad.
/// Anything synced through iCloud (from your iPhone or Mac) shows up here automatically.
@MainActor
final class CalendarService: ObservableObject {
    static let listName = "Kitchen"
    static let shoppingListName = "Shopping"

    @Published var events: [CalEvent] = []
    @Published var calendars: [CalInfo] = []
    @Published var todos: [TodoItem] = []
    @Published var shopping: [TodoItem] = []
    @Published var calendarAccess = false
    @Published var remindersAccess = false

    private let store = EKEventStore()
    private var started = false

    func start() async {
        guard !started else { return }
        started = true
        calendarAccess = (try? await store.requestFullAccessToEvents()) ?? false
        remindersAccess = (try? await store.requestFullAccessToReminders()) ?? false

        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
        reload()

        // Also refresh every 15 minutes, which covers the date rolling over.
        Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(900))
                self?.reload()
            }
        }
    }

    func reload() {
        loadEvents()
        loadTodos()
    }

    // MARK: Calendar

    private func loadEvents() {
        guard calendarAccess else { return }
        let cal = Calendar.current
        let now = Date()
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)),
              let start = cal.date(byAdding: .day, value: -7, to: monthStart),
              let end = cal.date(byAdding: .day, value: 75, to: monthStart) else { return }

        let all = store.calendars(for: .event)
        calendars = all.map { CalInfo(id: $0.calendarIdentifier, name: $0.title, color: Color(cgColor: $0.cgColor)) }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: all)
        events = store.events(matching: predicate).map { e in
            CalEvent(id: (e.eventIdentifier ?? UUID().uuidString) + "-\(e.startDate.timeIntervalSince1970)",
                     title: e.title ?? "Untitled",
                     start: e.startDate,
                     end: e.endDate,
                     isAllDay: e.isAllDay,
                     color: Color(cgColor: e.calendar.cgColor),
                     calendarID: e.calendar.calendarIdentifier)
        }
    }

    // MARK: Reminders (to-dos)

    /// Finds a list in Reminders by name ("Kitchen" or "Shopping"), creating it the first time.
    private func reminderList(named name: String) -> EKCalendar? {
        if let existing = store.calendars(for: .reminder).first(where: { $0.title == name }) {
            return existing
        }
        guard let source = store.defaultCalendarForNewReminders()?.source else { return nil }
        let list = EKCalendar(for: .reminder, eventStore: store)
        list.title = name
        list.source = source
        do {
            try store.saveCalendar(list, commit: true)
            return list
        } catch {
            return nil
        }
    }

    private func loadTodos() {
        loadItems(from: Self.listName) { [weak self] in self?.todos = $0 }
        loadItems(from: Self.shoppingListName) { [weak self] in self?.shopping = $0 }
    }

    private func loadItems(from name: String, assign: @escaping @MainActor ([TodoItem]) -> Void) {
        guard remindersAccess, let list = reminderList(named: name) else { return }
        let predicate = store.predicateForReminders(in: [list])
        let startOfToday = Calendar.current.startOfDay(for: Date())
        store.fetchReminders(matching: predicate) { reminders in
            // Open items first, then anything checked off today.
            let items: [TodoItem] = (reminders ?? [])
                .filter { !$0.isCompleted || ($0.completionDate ?? .distantPast) >= startOfToday }
                .sorted { a, b in
                    if a.isCompleted != b.isCompleted { return !a.isCompleted }
                    return (a.creationDate ?? .distantPast) < (b.creationDate ?? .distantPast)
                }
                .map { TodoItem(id: $0.calendarItemIdentifier, title: $0.title ?? "", done: $0.isCompleted) }
            Task { @MainActor in assign(items) }
        }
    }

    func toggleTodo(_ id: String) {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        reminder.isCompleted.toggle()
        try? store.save(reminder, commit: true)
        loadTodos()
    }

    func addTodo(_ title: String) {
        addItem(title, toList: Self.listName)
    }

    func addShoppingItem(_ title: String) {
        addItem(title, toList: Self.shoppingListName)
    }

    private func addItem(_ title: String, toList name: String) {
        guard remindersAccess, let list = reminderList(named: name) else { return }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = list
        try? store.save(reminder, commit: true)
        loadTodos()
    }
}
