import Combine
import CoreLocation
import SwiftUI

struct WeatherDay: Identifiable {
    let id: String
    let date: Date
    let code: Int
    let high: Double
    let low: Double
}

struct WeatherNow {
    let temp: Double
    let code: Int
    let isDay: Bool
    let days: [WeatherDay]
}

/// Current weather and a 4-day forecast from Open-Meteo (free, no account).
/// Uses the iPad's approximate location.
@MainActor
final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var current: WeatherNow?
    @Published var failed = false

    private let manager = CLLocationManager()
    private var latitude: Double?
    private var longitude: Double?
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.requestWhenInUseAuthorization()
        Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(900))
                await self?.refresh()
            }
        }
    }

    /// Tries again shortly after a failure, so a bad moment at launch doesn't leave the weather stuck.
    private func retrySoon() {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard let self, self.current == nil else { return }
            if self.latitude == nil {
                self.manager.requestLocation()
            } else {
                await self.refresh()
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        } else if status == .denied || status == .restricted {
            Task { @MainActor in self.failed = true }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let c = locations.last?.coordinate else { return }
        let lat = c.latitude, lon = c.longitude
        Task { @MainActor in
            self.latitude = lat
            self.longitude = lon
            await self.refresh()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if self.current == nil {
                self.failed = true
                self.retrySoon()
            }
        }
    }

    func refresh() async {
        guard let lat = latitude, let lon = longitude else { return }
        let unit = Locale.current.measurementSystem == .us ? "fahrenheit" : "celsius"
        var parts = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        parts.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.3f", lat)),
            URLQueryItem(name: "longitude", value: String(format: "%.3f", lon)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "temperature_unit", value: unit),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "4")
        ]
        guard let url = parts.url else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            let r = try JSONDecoder().decode(OpenMeteo.self, from: data)
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            var days: [WeatherDay] = []
            for i in r.daily.time.indices {
                guard let d = fmt.date(from: r.daily.time[i]) else { continue }
                days.append(WeatherDay(id: r.daily.time[i], date: d, code: r.daily.weather_code[i],
                                       high: r.daily.temperature_2m_max[i], low: r.daily.temperature_2m_min[i]))
            }
            current = WeatherNow(temp: r.current.temperature_2m, code: r.current.weather_code,
                                 isDay: r.current.is_day == 1, days: days)
            failed = false
        } catch {
            if current == nil {
                failed = true
                retrySoon()
            }
        }
    }
}

private struct OpenMeteo: Decodable {
    struct Current: Decodable {
        let temperature_2m: Double
        let weather_code: Int
        let is_day: Int
    }
    struct Daily: Decodable {
        let time: [String]
        let weather_code: [Int]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
    }
    let current: Current
    let daily: Daily
}

/// Turns Open-Meteo's weather codes into words and SF Symbols.
enum WeatherCode {
    static func label(_ code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1, 2: return "Partly cloudy"
        case 3: return "Cloudy"
        case 45, 48: return "Foggy"
        case 51...57: return "Drizzle"
        case 61...67: return "Rain"
        case 71...77: return "Snow"
        case 80...82: return "Showers"
        case 85, 86: return "Snow showers"
        case 95...99: return "Thunderstorms"
        default: return "Cloudy"
        }
    }

    static func symbol(_ code: Int, isDay: Bool = true) -> String {
        switch code {
        case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}
