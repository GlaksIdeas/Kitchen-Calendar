import Combine
import HomeKit
import SwiftUI

struct LightRoom: Identifiable {
    let id: UUID
    let name: String
    let isOn: Bool
    let brightness: Int
    /// At least one light in the room can show colors.
    let supportsColor: Bool
    /// At least one light in the room can shift between warm and cool white.
    let supportsWhiteTemperature: Bool
    /// The color the room's lights are showing right now (for the bulb icon), if known.
    let currentColor: Color?
}

struct HomeScene: Identifiable {
    let id: UUID
    let name: String
}

/// Your Apple Home rooms and scenes. Hue lights added to Apple Home appear here
/// with no extra setup. Only starts once "Home controls" is switched on in Settings.
@MainActor
final class HomeService: NSObject, ObservableObject, HMHomeManagerDelegate, HMAccessoryDelegate {
    @Published var rooms: [LightRoom] = []
    @Published var scenes: [HomeScene] = []
    @Published var status = "Connecting to Home…"

    private var manager: HMHomeManager?
    private var home: HMHome? { manager?.homes.first }

    private static let watched: Set<String> = [
        HMCharacteristicTypePowerState, HMCharacteristicTypeBrightness,
        HMCharacteristicTypeHue, HMCharacteristicTypeSaturation, HMCharacteristicTypeColorTemperature
    ]

    func start() {
        guard manager == nil else { return }
        let m = HMHomeManager()
        m.delegate = self
        manager = m
    }

    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in self.connect() }
    }

    nonisolated func accessory(_ accessory: HMAccessory, service: HMService, didUpdateValueFor characteristic: HMCharacteristic) {
        Task { @MainActor in self.rebuild() }
    }

    private func connect() {
        guard let home else {
            status = "No home found in the Home app"
            return
        }
        // Ask each light to report changes, so the panel matches reality.
        for accessory in home.accessories {
            accessory.delegate = self
            for service in lightServices(accessory) {
                for c in service.characteristics where Self.watched.contains(c.characteristicType) {
                    c.enableNotification(true) { _ in }
                    c.readValue { _ in Task { @MainActor in self.rebuild() } }
                }
            }
        }
        rebuild()
    }

    // MARK: Reading

    private func allRooms() -> [HMRoom] {
        guard let home else { return [] }
        return home.rooms + [home.roomForEntireHome()]
    }

    private func lightServices(_ accessory: HMAccessory) -> [HMService] {
        accessory.services.filter { $0.serviceType == HMServiceTypeLightbulb }
    }

    private func lights(in room: HMRoom) -> [HMService] {
        room.accessories.flatMap { lightServices($0) }
    }

    private func value(_ service: HMService, _ type: String) -> HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == type }
    }

    private func number(_ s: HMService, _ type: String) -> Double? {
        (value(s, type)?.value as? NSNumber)?.doubleValue
    }

    private func isOn(_ s: HMService) -> Bool { value(s, HMCharacteristicTypePowerState)?.value as? Bool ?? false }
    private func level(_ s: HMService) -> Int? { number(s, HMCharacteristicTypeBrightness).map { Int($0) } }
    private func hasColor(_ s: HMService) -> Bool { value(s, HMCharacteristicTypeHue) != nil }
    private func hasTemperature(_ s: HMService) -> Bool { value(s, HMCharacteristicTypeColorTemperature) != nil }

    /// What the light looks like now: its color, or a warm/cool white.
    private func displayColor(_ s: HMService) -> Color? {
        if let hue = number(s, HMCharacteristicTypeHue), let sat = number(s, HMCharacteristicTypeSaturation), sat > 12 {
            return Color(hue: hue / 360, saturation: min(sat / 100, 1), brightness: 1)
        }
        if let mired = number(s, HMCharacteristicTypeColorTemperature) {
            let warmth = min(max((mired - 153) / (500 - 153), 0), 1)
            return Self.white(warmth: warmth)
        }
        return nil
    }

    /// 0 = cool daylight, 1 = warm candlelight.
    static func white(warmth: Double) -> Color {
        Color(hue: 0.09, saturation: 0.05 + warmth * 0.55, brightness: 1)
    }

    private func rebuild() {
        guard let home else { return }
        rooms = allRooms().compactMap { room in
            let ls = lights(in: room)
            guard !ls.isEmpty else { return nil }
            let lit = ls.filter { isOn($0) }
            let levels = lit.compactMap { level($0) }
            let avg = levels.isEmpty ? (lit.isEmpty ? 0 : 100) : levels.reduce(0, +) / levels.count
            return LightRoom(id: room.uniqueIdentifier,
                             name: room.name,
                             isOn: !lit.isEmpty,
                             brightness: avg,
                             supportsColor: ls.contains { hasColor($0) },
                             supportsWhiteTemperature: ls.contains { hasTemperature($0) },
                             currentColor: lit.first.flatMap { displayColor($0) })
        }
        scenes = home.actionSets
            .filter { !$0.actions.isEmpty }
            .map { HomeScene(id: $0.uniqueIdentifier, name: $0.name) }
        status = rooms.isEmpty ? "No lights found in the Home app" : ""
    }

    // MARK: Changing lights

    private func room(_ id: UUID) -> HMRoom? { allRooms().first { $0.uniqueIdentifier == id } }

    private func write(_ c: HMCharacteristic?, _ newValue: Any) {
        c?.writeValue(newValue) { _ in Task { @MainActor in self.rebuild() } }
    }

    func setRoom(_ id: UUID, on: Bool) {
        guard let room = room(id) else { return }
        for s in lights(in: room) { write(value(s, HMCharacteristicTypePowerState), on) }
    }

    func setBrightness(_ id: UUID, _ percent: Int) {
        guard let room = room(id) else { return }
        if percent == 0 { setRoom(id, on: false); return }
        for s in lights(in: room) {
            write(value(s, HMCharacteristicTypePowerState), true)
            write(value(s, HMCharacteristicTypeBrightness), percent)
        }
    }

    /// Hue in degrees (0–360), saturation in percent (0–100).
    func setColor(_ id: UUID, hue: Double, saturation: Double) {
        guard let room = room(id) else { return }
        for s in lights(in: room) where hasColor(s) {
            write(value(s, HMCharacteristicTypePowerState), true)
            write(value(s, HMCharacteristicTypeHue), Float(hue))
            write(value(s, HMCharacteristicTypeSaturation), Float(saturation))
        }
    }

    /// 0 = cool daylight, 1 = warm candlelight. Uses each light's own supported range.
    func setWhite(_ id: UUID, warmth: Double) {
        guard let room = room(id) else { return }
        for s in lights(in: room) {
            if let c = value(s, HMCharacteristicTypeColorTemperature) {
                let lo = c.metadata?.minimumValue?.doubleValue ?? 153
                let hi = c.metadata?.maximumValue?.doubleValue ?? 500
                write(value(s, HMCharacteristicTypePowerState), true)
                write(c, Int((lo + warmth * (hi - lo)).rounded()))
            } else if hasColor(s) {
                // Color-only bulbs: fake a white with a pale orange.
                write(value(s, HMCharacteristicTypePowerState), true)
                write(value(s, HMCharacteristicTypeHue), Float(30))
                write(value(s, HMCharacteristicTypeSaturation), Float(warmth * 60))
            }
        }
    }

    func allOff() {
        for r in rooms where r.isOn { setRoom(r.id, on: false) }
    }

    func run(_ sceneID: UUID) {
        guard let home, let set = home.actionSets.first(where: { $0.uniqueIdentifier == sceneID }) else { return }
        home.executeActionSet(set) { _ in Task { @MainActor in self.rebuild() } }
    }
}
