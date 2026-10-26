import SwiftUI
import UIKit

/// Opens from the palette button on a room tile: color swatches, a full color
/// picker, and a warm-to-cool slider for white light.
struct LightColorSheet: View {
    let roomID: UUID
    let theme: Theme

    @EnvironmentObject var home: HomeService
    @Environment(\.dismiss) private var dismiss
    @State private var picked: Color = .white
    @State private var warmth: Double = 0.6
    @State private var pending: Task<Void, Never>?

    private struct Swatch: Identifiable {
        let name: String
        let hue: Double
        let saturation: Double
        var id: String { name }
        var color: Color { Color(hue: hue / 360, saturation: saturation / 100, brightness: 1) }
    }

    private let colors = [
        Swatch(name: "Red", hue: 0, saturation: 100),
        Swatch(name: "Orange", hue: 28, saturation: 100),
        Swatch(name: "Gold", hue: 45, saturation: 90),
        Swatch(name: "Green", hue: 120, saturation: 85),
        Swatch(name: "Teal", hue: 175, saturation: 80),
        Swatch(name: "Blue", hue: 225, saturation: 100),
        Swatch(name: "Purple", hue: 275, saturation: 90),
        Swatch(name: "Pink", hue: 320, saturation: 65)
    ]

    private let whites: [(name: String, warmth: Double)] = [
        ("Candle", 1.0), ("Warm", 0.75), ("Neutral", 0.45), ("Daylight", 0.0)
    ]

    private var room: LightRoom? { home.rooms.first { $0.id == roomID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if let room {
                        if room.supportsColor {
                            colorSection
                        }
                        if room.supportsColor || room.supportsWhiteTemperature {
                            whiteSection
                        } else {
                            Text("The lights in this room only change brightness.")
                                .font(.system(size: 18))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }
                .padding(24)
            }
            .background(theme.ground)
            .navigationTitle(room?.name ?? "Lights")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel("Colors", size: 17)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 16) {
                ForEach(colors) { swatch in
                    Button {
                        home.setColor(roomID, hue: swatch.hue, saturation: swatch.saturation)
                    } label: {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(swatch.color)
                                .frame(width: 56, height: 56)
                                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 2))
                            Text(swatch.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Theme.fg)
                        }
                        .frame(maxWidth: .infinity, minHeight: 88)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Set \(room?.name ?? "") lights to \(swatch.name)")
                }
            }
            ColorPicker(selection: $picked, supportsOpacity: false) {
                Text("Pick any color")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.fg)
            }
            .frame(minHeight: 44)
            .onChange(of: picked) { _, newColor in sendPicked(newColor) }
        }
    }

    private var whiteSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel("White light", size: 17)
            HStack(spacing: 10) {
                ForEach(whites, id: \.name) { w in
                    Button {
                        warmth = w.warmth
                        home.setWhite(roomID, warmth: w.warmth)
                    } label: {
                        Text(w.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(theme.ground)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(HomeService.white(warmth: w.warmth),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 12) {
                Text("Cool").font(.system(size: 15)).foregroundStyle(Theme.muted)
                Slider(value: $warmth, in: 0...1, onEditingChanged: { editing in
                    if !editing { home.setWhite(roomID, warmth: warmth) }
                })
                .tint(theme.accent)
                .accessibilityLabel("Warmth")
                Text("Warm").font(.system(size: 15)).foregroundStyle(Theme.muted)
            }
        }
    }

    /// The color picker reports every tiny change while you drag, so wait a beat
    /// and send only the color you settle on.
    private func sendPicked(_ color: Color) {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(color).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            home.setColor(roomID, hue: Double(h) * 360, saturation: Double(s) * 100)
        }
    }
}
