import SwiftUI

/// What the TV shows. Look-only: no buttons.
/// Designed at 1080 × 1920 (portrait) and scaled to whatever the TV reports.
struct TVDisplayView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        GeometryReader { geo in
            let portrait = model.tvRotation != 0
            let canvas = portrait ? CGSize(width: geo.size.height, height: geo.size.width) : geo.size
            let scale = min(canvas.width / TVLayout.size.width, canvas.height / TVLayout.size.height)
            TVLayout()
                .scaleEffect(scale)
                .frame(width: canvas.width, height: canvas.height)
                .rotationEffect(.degrees(Double(model.tvRotation)))
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .background(model.theme.ground)
        .overlay {
            // Night mode: the TV goes dark until morning (or until someone taps the iPad).
            if model.isNight {
                Color.black.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 1), value: model.isNight)
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
}

struct TVLayout: View {
    static let size = CGSize(width: 1080, height: 1920)

    @EnvironmentObject var model: AppModel
    @EnvironmentObject var cal: CalendarService

    var body: some View {
        let t = model.theme
        ZStack(alignment: .topLeading) {
            t.ground
            DecorLayer(theme: t, spots: DecorLayer.tvSpots)
            if let list = model.focusedList {
                focusedBody(t, list)
            } else if model.planningMode {
                planningBody(t)
            } else {
                regularBody(t)
            }
            GhostOverlay()
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .foregroundStyle(Theme.fg)
    }

    /// Current and next month, each taking half the screen, with more events per day.
    private func planningBody(_ t: Theme) -> some View {
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: model.now) ?? model.now
        return VStack(alignment: .leading, spacing: 20) {
            PlanningHeader(theme: t)
            MonthCalendar(theme: t, month: model.now, maxEvents: 4) { day in model.events(on: day) }
                .frame(maxHeight: .infinity, alignment: .top)
                .card(t, padding: 20)
            MonthCalendar(theme: t, month: nextMonth, maxEvents: 4) { day in model.events(on: day) }
                .frame(maxHeight: .infinity, alignment: .top)
                .card(t, padding: 20)
        }
        .padding(.top, 56)
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
    }

    /// One list taking the whole screen, with every item shown.
    private func focusedBody(_ t: Theme, _ list: FocusedList) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            PlanningHeader(theme: t, label: list.title.uppercased())
            FullTodoList(theme: t,
                         title: list.title,
                         todos: list == .todo ? cal.todos : cal.shopping,
                         available: cal.remindersAccess)
        }
        .padding(.top, 56)
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
    }

    private func regularBody(_ t: Theme) -> some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 20) {
                // Today sits close under the clock; the space saved goes to the calendar.
                VStack(alignment: .leading, spacing: 0) {
                    TVHeader(theme: t)
                    TodayCard(theme: t, events: model.events(on: model.now), now: model.now, legend: model.legendCalendars)
                }
                MonthCalendar(theme: t, month: model.now, textScale: 1.3) { day in model.events(on: day) }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .card(t, padding: 26)
                HStack(alignment: .top, spacing: 24) {
                    DinnerSummary(theme: t, dinner: model.dinner)
                    TodoSummary(theme: t, title: "To do", todos: cal.todos, available: cal.remindersAccess)
                    TodoSummary(theme: t, title: "Shopping", todos: cal.shopping, available: cal.remindersAccess)
                }
                .fixedSize(horizontal: false, vertical: true)
                TriviaCard(theme: t, fact: DailyContent.trivia(for: model.now))
            }
            .padding(.top, 32)
            .padding(.horizontal, 64)
            .padding(.bottom, 56)
        }
    }
}

/// Slim header for the planning view: clock and date on one line.
struct PlanningHeader: View {
    let theme: Theme
    var label = "PLANNING"

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let p = ClockText.parts(context.date)
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text("\(p.time) \(p.ampm)")
                    .font(Theme.woodland(54))
                Text(context.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(Theme.woodland(34))
                    .foregroundStyle(theme.accent)
                Spacer(minLength: 0)
                Text(label)
                    .font(Theme.woodland(22))
                    .tracking(2)
                    .foregroundStyle(Theme.muted)
            }
        }
    }
}

// MARK: - Clock and weather

enum ClockText {
    static func parts(_ date: Date) -> (time: String, ampm: String) {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        let h = c.hour ?? 0
        let hour12 = h % 12 == 0 ? 12 : h % 12
        return ("\(hour12):" + String(format: "%02d", c.minute ?? 0), h >= 12 ? "PM" : "AM")
    }
}

struct TVHeader: View {
    let theme: Theme
    @EnvironmentObject var weather: WeatherService

    var body: some View {
        HStack(alignment: .top, spacing: 32) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let p = ClockText.parts(context.date)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        // Papyrus ships with iOS; gives the clock a rustic, woodland-storybook look.
                        Text(p.time)
                            .font(.custom("Papyrus", size: 176))
                            .tracking(-2)
                        Text(p.ampm)
                            .font(.custom("Papyrus", size: 52))
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
            Spacer(minLength: 0)
            weatherBlock
        }
    }

    @ViewBuilder private var weatherBlock: some View {
        if let w = weather.current {
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 18) {
                    Image(systemName: WeatherCode.symbol(w.code, isDay: w.isDay))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 72))
                    Text("\(Int(w.temp.rounded()))°")
                        .font(.system(size: 84, weight: .semibold))
                }
                if let today = w.days.first {
                    Text("\(WeatherCode.label(w.code)) · H \(Int(today.high.rounded()))° L \(Int(today.low.rounded()))°")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.muted)
                }
                HStack(spacing: 12) {
                    ForEach(w.days.dropFirst().prefix(3)) { d in
                        VStack(spacing: 4) {
                            Text(d.date.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Theme.muted)
                            Image(systemName: WeatherCode.symbol(d.code))
                                .symbolRenderingMode(.multicolor)
                                .font(.system(size: 30))
                            Text("\(Int(d.high.rounded()))°")
                                .font(.system(size: 28, weight: .semibold))
                            Text("\(Int(d.low.rounded()))°")
                                .font(.system(size: 18))
                                .foregroundStyle(Theme.muted)
                        }
                        .frame(width: 92)
                        .padding(.vertical, 8)
                        .background(theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
        } else {
            Text(weather.failed ? "Weather unavailable" : "Loading weather…")
                .font(.system(size: 24))
                .foregroundStyle(Theme.muted)
                .padding(.top, 40)
        }
    }
}

// MARK: - Today

struct TodayCard: View {
    let theme: Theme
    let events: [CalEvent]
    let now: Date
    let legend: [CalInfo]

    private struct Row: Identifiable {
        let id: String
        let event: CalEvent
        let past: Bool
        let flag: String?
    }

    /// Up to five events; older ones drop off first when the day is busy.
    private var rows: [Row] {
        var list = events
        while list.count > 5, let first = list.first, !first.isAllDay, first.end <= now {
            list.removeFirst()
        }
        var flagged = false
        return list.prefix(5).map { e in
            let past = !e.isAllDay && e.end <= now
            var flag: String?
            if !e.isAllDay && !past && !flagged {
                flagged = true
                flag = e.start <= now ? "NOW" : "NEXT"
            }
            return Row(id: e.id, event: e, past: past, flag: flag)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                SectionLabel("Today", woodland: true)
                Spacer()
                Text(now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(Theme.woodland(30))
                    .foregroundStyle(theme.accent)
            }
            let list = rows
            if list.isEmpty {
                Text("Nothing on the calendar today")
                    .font(Theme.woodland(27))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
            }
            ForEach(list) { r in
                HStack(spacing: 16) {
                    Circle().fill(r.event.color).frame(width: 14, height: 14)
                    Text(r.event.isAllDay ? "All day" : r.event.start.formatted(date: .omitted, time: .shortened))
                        .font(Theme.woodland(26))
                        .frame(width: 140, alignment: .leading)
                    Text(r.event.title)
                        .font(Theme.woodland(28))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 8)
                    if let flag = r.flag {
                        Text(flag)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(theme.ground)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(theme.accent, in: Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(r.flag != nil ? theme.chip : Color.clear,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .opacity(r.past ? 0.45 : 1)
            }
            if !legend.isEmpty {
                HStack(spacing: 22) {
                    ForEach(legend.prefix(4)) { c in
                        HStack(spacing: 8) {
                            Circle().fill(c.color).frame(width: 12, height: 12)
                            Text(c.name).lineLimit(1)
                        }
                    }
                }
                .font(.system(size: 20))
                .foregroundStyle(Theme.muted)
                .padding(.top, 2)
            }
        }
        .card(theme, padding: 24)
    }
}

// MARK: - Month

struct MonthCalendar: View {
    let theme: Theme
    let month: Date
    var maxEvents = 2
    /// Scales the text in each day; the regular view uses it to make the calendar easier to read.
    var textScale: CGFloat = 1
    let eventsOn: @MainActor (Date) -> [CalEvent]

    var body: some View {
        let cal = Calendar.current
        let first = cal.date(from: cal.dateComponents([.year, .month], from: month)) ?? month
        let lead = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        let dayCount = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let rows = (lead + dayCount + 6) / 7
        let gridStart = cal.date(byAdding: .day, value: -lead, to: first) ?? first
        let symbols = cal.shortWeekdaySymbols
        let weekdays = (0..<7).map { symbols[($0 + cal.firstWeekday - 1) % 7].uppercased() }
        let today = cal.startOfDay(for: Date())

        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(first.formatted(.dateTime.month(.wide).year()))
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    ForEach(weekdays, id: \.self) { w in
                        Text(w)
                            .font(.system(size: 18, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity)
                    }
                }
                ForEach(0..<rows, id: \.self) { r in
                    GridRow {
                        ForEach(0..<7, id: \.self) { c in
                            let day = cal.date(byAdding: .day, value: r * 7 + c, to: gridStart) ?? gridStart
                            DayCell(theme: theme,
                                    day: day,
                                    inMonth: cal.isDate(day, equalTo: first, toGranularity: .month),
                                    isToday: cal.isDate(day, inSameDayAs: today),
                                    isPast: day < today,
                                    events: eventsOn(day),
                                    maxEvents: maxEvents,
                                    textScale: textScale)
                        }
                    }
                }
            }
        }
    }
}

struct DayCell: View {
    let theme: Theme
    let day: Date
    let inMonth: Bool
    let isToday: Bool
    let isPast: Bool
    let events: [CalEvent]
    var maxEvents = 2
    var textScale: CGFloat = 1

    var body: some View {
        let shown = inMonth ? Array(events.prefix(maxEvents)) : []
        VStack(alignment: .leading, spacing: 4) {
            Text("\(Calendar.current.component(.day, from: day))")
                .font(.system(size: 22 * textScale, weight: .semibold))
                .foregroundStyle(isToday ? theme.accent : Theme.fg)
            ForEach(shown) { e in
                HStack(spacing: 6) {
                    Circle().fill(e.color).frame(width: 8 * textScale, height: 8 * textScale)
                    Text(e.title).lineLimit(1)
                }
                .font(.system(size: 16 * textScale))
            }
            if inMonth && events.count > maxEvents {
                Text("+\(events.count - maxEvents) more")
                    .font(.system(size: 15 * textScale))
                    .foregroundStyle(Theme.muted)
                    .padding(.leading, 14)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(isToday ? theme.chip : Color.white.opacity(0.035),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(theme.accent, lineWidth: 3)
            }
        }
        .opacity(!inMonth ? 0.25 : (isPast ? 0.5 : 1))
    }
}

// MARK: - Dinner, to-dos, trivia

struct DinnerSummary: View {
    let theme: Theme
    let dinner: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Dinner tonight", size: 24, woodland: true)
            Text(dinner.isEmpty ? "Not planned yet" : dinner)
                .font(Theme.woodland(46))
                .foregroundStyle(dinner.isEmpty ? Theme.muted : Theme.fg)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .card(theme, padding: 28)
    }
}

struct TodoSummary: View {
    let theme: Theme
    let title: String
    let todos: [TodoItem]
    let available: Bool

    var body: some View {
        let open = todos.filter { !$0.done }.count
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionLabel(title, size: 24, woodland: true)
                Spacer()
                Text(open == 0 ? "All done" : "\(open) left")
                    .font(Theme.woodland(20))
                    .foregroundStyle(Theme.muted)
            }
            if !available {
                Text("Allow Reminders access on the iPad")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.muted)
            }
            ForEach(todos.prefix(5)) { item in
                HStack(spacing: 14) {
                    ZStack {
                        if item.done {
                            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(theme.accent)
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundStyle(theme.ground)
                        } else {
                            RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Theme.faint, lineWidth: 3)
                        }
                    }
                    .frame(width: 30, height: 30)
                    Text(item.title)
                        .font(Theme.woodland(26))
                        .strikethrough(item.done)
                        .foregroundStyle(item.done ? Theme.faint : Theme.fg)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .card(theme, padding: 28)
    }
}

/// Full-screen version of TodoSummary: every item, larger, in two columns when the list is long.
struct FullTodoList: View {
    let theme: Theme
    let title: String
    let todos: [TodoItem]
    let available: Bool

    var body: some View {
        let open = todos.filter { !$0.done }.count
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                SectionLabel(title, size: 40, woodland: true)
                Spacer()
                Text(open == 0 ? "All done" : "\(open) left")
                    .font(Theme.woodland(32))
                    .foregroundStyle(Theme.muted)
            }
            if !available {
                Text("Allow Reminders access on the iPad")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.muted)
            } else if todos.isEmpty {
                Text("Nothing here yet")
                    .font(Theme.woodland(36))
                    .foregroundStyle(Theme.muted)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 32, alignment: .top),
                                     count: todos.count > 16 ? 2 : 1),
                      alignment: .leading, spacing: 22) {
                ForEach(todos) { item in
                    HStack(spacing: 20) {
                        ZStack {
                            if item.done {
                                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(theme.accent)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 22, weight: .heavy))
                                    .foregroundStyle(theme.ground)
                            } else {
                                RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.faint, lineWidth: 4)
                            }
                        }
                        .frame(width: 44, height: 44)
                        Text(item.title)
                            .font(Theme.woodland(40))
                            .strikethrough(item.done)
                            .foregroundStyle(item.done ? Theme.faint : Theme.fg)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                        Spacer(minLength: 0)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card(theme, padding: 40)
    }
}

struct TriviaCard: View {
    let theme: Theme
    let fact: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Did you know?", size: 24, woodland: true)
            Text(fact)
                .font(Theme.woodland(29))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card(theme, padding: 30)
    }
}
