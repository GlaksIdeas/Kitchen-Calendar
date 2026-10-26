import SwiftUI

/// What the iPad shows: lights, scenes, dinner and to-dos.
struct ControlPanelView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var cal: CalendarService
    @EnvironmentObject var weather: WeatherService
    @EnvironmentObject var home: HomeService
    @State private var showSettings = false

    var body: some View {
        let t = model.theme
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            ZStack {
                t.ground.ignoresSafeArea()
                DecorLayer(theme: t, spots: DecorLayer.panelSpots(geo.size))
                VStack(spacing: 22) {
                    PanelHeader(theme: t, showSettings: $showSettings)
                    if wide {
                        HStack(alignment: .top, spacing: 22) {
                            LightsPanel(theme: t)
                            VStack(spacing: 22) {
                                DinnerEditor(theme: t)
                                TodoPanel(theme: t)
                                TodoPanel(theme: t, kind: .shopping)
                            }
                            .frame(width: geo.size.width * 0.34)
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 22) {
                                LightsPanel(theme: t)
                                DinnerEditor(theme: t)
                                TodoPanel(theme: t).frame(minHeight: 360)
                                TodoPanel(theme: t, kind: .shopping).frame(minHeight: 360)
                            }
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
                GhostOverlay()

                if model.isNight {
                    NightCover()
                } else if model.isIdle {
                    ScreensaverView(theme: t)
                }
            }
            .animation(.easeInOut(duration: 0.6), value: model.isNight)
            .animation(.easeInOut(duration: 1.0), value: model.isIdle)
        }
        // Any touch resets the one-minute idle timer, without getting in the way of the controls.
        .background(TouchActivityObserver { model.noteActivity() })
        .foregroundStyle(Theme.fg)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(model)
                .environmentObject(cal)
        }
    }
}

/// Covers the iPad overnight. A tap wakes it for five minutes.
struct NightCover: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Button {
            model.wakeBriefly()
        } label: {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 14) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 44))
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        let p = ClockText.parts(context.date)
                        Text("\(p.time) \(p.ampm)")
                            .font(.system(size: 34, weight: .semibold))
                            .monospacedDigit()
                    }
                    Text("Tap to wake")
                        .font(.system(size: 18))
                }
                .foregroundStyle(Theme.fg.opacity(0.45))
            }
        }
        .buttonStyle(.plain)
        .transition(.opacity)
        .accessibilityLabel("Night mode. Tap to wake for five minutes.")
    }
}

/// Reports every touch in the window without ever claiming it, so sliders, buttons and
/// scrolling keep working exactly as before.
struct TouchActivityObserver: UIViewRepresentable {
    let onTouch: () -> Void

    func makeUIView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onTouch = onTouch
        return view
    }

    func updateUIView(_ view: ObserverView, context: Context) {
        view.onTouch = onTouch
    }

    final class ObserverView: UIView {
        var onTouch: (() -> Void)?
        private var recognizer: PassiveTouchRecognizer?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let recognizer { recognizer.view?.removeGestureRecognizer(recognizer) }
            recognizer = nil
            guard let window else { return }
            let r = PassiveTouchRecognizer { [weak self] in self?.onTouch?() }
            window.addGestureRecognizer(r)
            recognizer = r
        }
    }

    /// Sees touches but fails as soon as they end, and never cancels or delays them.
    final class PassiveTouchRecognizer: UIGestureRecognizer {
        private let handler: () -> Void

        init(handler: @escaping () -> Void) {
            self.handler = handler
            super.init(target: nil, action: nil)
            cancelsTouchesInView = false
            delaysTouchesBegan = false
            delaysTouchesEnded = false
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) { handler() }
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) { handler() }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { state = .failed }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { state = .failed }
    }
}

/// Shown after a minute idle: the season's shapes drift down around a slowly wandering
/// clock (moving keeps the screen from burning in). A touch wakes the iPad.
struct ScreensaverView: View {
    let theme: Theme
    @EnvironmentObject var model: AppModel

    private let count = 14

    var body: some View {
        Button {
            model.noteActivity()
        } label: {
            ZStack {
                Color.black.ignoresSafeArea()
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    GeometryReader { geo in
                        ZStack {
                            ForEach(0..<count, id: \.self) { i in
                                flake(i, t: t, size: geo.size)
                            }
                            clock(t: t, size: geo.size)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .transition(.opacity)
        .accessibilityLabel("Screensaver. Tap to wake.")
    }

    /// One drifting shape; every value is derived from its index so each moves differently.
    private func flake(_ i: Int, t: Double, size: CGSize) -> some View {
        let n = Double(i)
        let fall = 18 + (n.truncatingRemainder(dividingBy: 4)) * 7        // points per second
        let travel = size.height + 160
        let y = (t * fall + n * 97).truncatingRemainder(dividingBy: travel) - 80
        let baseX = ((n * 0.173 + 0.07).truncatingRemainder(dividingBy: 1)) * size.width
        let x = baseX + sin(t * 0.5 + n) * 28
        let spin = sin(t * 0.4 + n * 1.7) * 35
        return Image(systemName: theme.symbol)
            .font(.system(size: 26 + (n.truncatingRemainder(dividingBy: 3)) * 12))
            .foregroundStyle(theme.decor[i % theme.decor.count])
            .opacity(0.5)
            .rotationEffect(.degrees(spin))
            .position(x: x, y: y)
    }

    private func clock(t: Double, size: CGSize) -> some View {
        let p = ClockText.parts(Date())
        let x = size.width / 2 + sin(t / 23) * size.width * 0.18
        let y = size.height / 2 + cos(t / 31) * size.height * 0.18
        return VStack(spacing: 6) {
            Text("\(p.time) \(p.ampm)")
                .font(.system(size: 54, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text("z z z")
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(theme.accent)
        }
        .foregroundStyle(Theme.fg.opacity(0.7))
        .position(x: x, y: y)
    }
}

struct PanelHeader: View {
    let theme: Theme
    @Binding var showSettings: Bool
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var weather: WeatherService

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let p = ClockText.parts(context.date)
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text("\(p.time) \(p.ampm)")
                        .font(.system(size: 46, weight: .semibold))
                        .monospacedDigit()
                    Text(context.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(theme.accent)
                }
            }
            Spacer()
            if let w = weather.current {
                HStack(spacing: 8) {
                    Image(systemName: WeatherCode.symbol(w.code, isDay: w.isDay)).symbolRenderingMode(.multicolor)
                    Text("\(Int(w.temp.rounded()))°").fontWeight(.semibold)
                }
                .font(.system(size: 24))
            }
            Label(model.tvConnected ? "TV on" : "TV not connected", systemImage: "tv")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(model.tvConnected ? Theme.fg : Theme.muted)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(theme.card, in: Capsule())
            Button {
                withAnimation { model.planningMode.toggle() }
            } label: {
                Label("Plan", systemImage: model.planningMode ? "calendar.badge.checkmark" : "calendar")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(model.planningMode ? theme.ground : Theme.fg)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(model.planningMode ? theme.accent : theme.card, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Planning view on TV")
            .accessibilityValue(model.planningMode ? "On" : "Off")
            ListFocusButton(theme: theme, list: .todo)
            ListFocusButton(theme: theme, list: .shopping)
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22))
                    .frame(width: 44, height: 44)
                    .background(theme.card, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
    }
}

/// Header button that blows a list up full screen on the TV; tap again to go back.
struct ListFocusButton: View {
    let theme: Theme
    let list: FocusedList
    @EnvironmentObject var model: AppModel

    var body: some View {
        let on = model.focusedList == list
        Button {
            withAnimation { model.focusedList = on ? nil : list }
        } label: {
            Label(list.title, systemImage: list.symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(on ? theme.ground : Theme.fg)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(on ? theme.accent : theme.card, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(list.title) list full screen on TV")
        .accessibilityValue(on ? "On" : "Off")
    }
}

// MARK: - Lights

struct LightsPanel: View {
    let theme: Theme
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var home: HomeService

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                SectionLabel("Lights", size: 20)
                Spacer()
                if model.homeEnabled && !home.rooms.isEmpty {
                    Button("All off") { home.allOff() }
                        .buttonStyle(OutlinePillStyle())
                }
            }
            if !model.homeEnabled {
                message("Turn on Home controls in Settings to use your Hue lights here.")
            } else if home.rooms.isEmpty {
                message(home.status)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(home.rooms) { room in
                        RoomTile(room: room, theme: theme)
                    }
                }
                if !home.scenes.isEmpty {
                    SectionLabel("Scenes", size: 17)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(home.scenes) { scene in
                                Button(scene.name) { home.run(scene.id) }
                                    .buttonStyle(ChipStyle(theme: theme))
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .card(theme, padding: 24, radius: 26)
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 19))
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct RoomTile: View {
    let room: LightRoom
    let theme: Theme
    @EnvironmentObject var home: HomeService
    @State private var level: Double = 0
    @State private var editing = false
    @State private var showColors = false
    @State private var lastSent = Date.distantPast

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 4) {
                Button {
                    home.setRoom(room.id, on: !room.isOn)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: room.isOn ? "lightbulb.fill" : "lightbulb")
                            .font(.system(size: 28))
                            .foregroundStyle(room.isOn ? (room.currentColor ?? theme.accent) : Theme.faint)
                        Text(room.name)
                            .font(.system(size: 20, weight: .semibold))
                            .lineLimit(1)
                        Text(room.isOn ? "\(room.brightness)%" : "Off")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(room.name) lights")
                .accessibilityValue(room.isOn ? "On" : "Off")

                if room.supportsColor || room.supportsWhiteTemperature {
                    Button {
                        showColors = true
                    } label: {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.fg)
                            .frame(width: 44, height: 44)
                            .background(theme.card, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(room.name) light color")
                }
            }

            Slider(value: $level, in: 0...100, step: 1, onEditingChanged: { isEditing in
                editing = isEditing
                if !isEditing { home.setBrightness(room.id, Int(level)) }   // final value on release
            })
            .onChange(of: level) { _, newValue in
                // Dim live while dragging, at most a few times a second so the lights keep up.
                guard editing, Date().timeIntervalSince(lastSent) > 0.15 else { return }
                lastSent = Date()
                home.setBrightness(room.id, Int(newValue))
            }
            .tint(theme.accent)
            .accessibilityLabel("\(room.name) brightness")
        }
        .padding(16)
        .background(room.isOn ? theme.lit : theme.chip, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear { level = Double(room.isOn ? room.brightness : 0) }
        .onChange(of: room.brightness) { _, newValue in
            if !editing { level = Double(room.isOn ? newValue : 0) }
        }
        .onChange(of: room.isOn) { _, on in
            if !editing { level = Double(on ? room.brightness : 0) }
        }
        .sheet(isPresented: $showColors) {
            LightColorSheet(roomID: room.id, theme: theme)
                .environmentObject(home)
        }
    }
}

// MARK: - Dinner

struct DinnerEditor: View {
    let theme: Theme
    @EnvironmentObject var model: AppModel
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Dinner tonight", size: 18, woodland: true)
            Text(model.dinner.isEmpty ? "Not planned yet" : model.dinner)
                .font(Theme.woodland(30))
                .foregroundStyle(model.dinner.isEmpty ? Theme.muted : Theme.fg)
                .lineLimit(2)
            HStack(spacing: 10) {
                TextField("Change dinner…", text: $draft)
                    .panelField(theme)
                    .submitLabel(.done)
                    .onSubmit(save)
                Button("Set", action: save)
                    .buttonStyle(PrimaryStyle(theme: theme))
            }
        }
        .card(theme, padding: 22, radius: 26)
    }

    private func save() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        model.dinner = text
        draft = ""
    }
}

// MARK: - To-dos

enum ChecklistKind {
    case todo, shopping

    var title: String { self == .todo ? "To do" : "Shopping" }
    var placeholder: String { self == .todo ? "Add a to-do…" : "Add to shopping list…" }
}

struct TodoPanel: View {
    let theme: Theme
    var kind: ChecklistKind = .todo
    @EnvironmentObject var cal: CalendarService
    @State private var draft = ""

    private var items: [TodoItem] { kind == .todo ? cal.todos : cal.shopping }

    var body: some View {
        let open = items.filter { !$0.done }.count
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SectionLabel(kind.title, size: 18, woodland: true)
                Spacer()
                Text(open == 0 ? "All done" : "\(open) left")
                    .font(Theme.woodland(16))
                    .foregroundStyle(Theme.muted)
            }
            if !cal.remindersAccess {
                Text("Allow Reminders access in the iPad’s Settings › Privacy & Security › Reminders.")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.muted)
            }
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        Button {
                            cal.toggleTodo(item.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.done ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 26))
                                    .foregroundStyle(item.done ? theme.accent : Theme.faint)
                                Text(item.title)
                                    .font(Theme.woodland(20))
                                    .strikethrough(item.done)
                                    .foregroundStyle(item.done ? Theme.faint : Theme.fg)
                                    .lineLimit(2)
                                Spacer(minLength: 0)
                            }
                            .frame(minHeight: 48)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(item.done ? "Done" : "Not done")
                    }
                }
            }
            HStack(spacing: 10) {
                TextField(kind.placeholder, text: $draft)
                    .panelField(theme)
                    .submitLabel(.done)
                    .onSubmit(add)
                Button("Add", action: add)
                    .buttonStyle(PrimaryStyle(theme: theme))
            }
            .padding(.top, 6)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .card(theme, padding: 22, radius: 26)
    }

    private func add() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if kind == .todo { cal.addTodo(text) } else { cal.addShoppingItem(text) }
        draft = ""
    }
}

// MARK: - Button styles

struct PrimaryStyle: ButtonStyle {
    let theme: Theme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(theme.ground)
            .padding(.horizontal, 18)
            .frame(minWidth: 64, minHeight: 44)
            .background(theme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct ChipStyle: ButtonStyle {
    let theme: Theme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(configuration.isPressed ? theme.ground : Theme.fg)
            .padding(.horizontal, 22)
            .frame(minHeight: 48)
            .background(configuration.isPressed ? theme.accent : theme.chip, in: Capsule())
    }
}

struct OutlinePillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .padding(.horizontal, 20)
            .frame(minHeight: 44)
            .overlay(Capsule().stroke(Theme.faint, lineWidth: 2))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
