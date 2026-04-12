//
//  WeatherService.swift
//  house connect
//
//  Live weather data for the Home dashboard card. Uses the Open-Meteo
//  API (https://open-meteo.com) — free, no API key, no signup. Returns
//  current temperature, WMO weather code, and a human-readable
//  condition string. Falls back to the old hardcoded placeholder
//  gracefully on any failure (no location permission, no internet,
//  malformed response) so the card never shows a spinner or error.
//
//  Design decisions:
//  -----------------
//  - CoreLocation is requested at `whenInUse` level. We only need one
//    fix to seed the forecast; we don't track the user's location
//    continuously. The delegate fires once, fetches, then stops
//    updating.
//  - We fetch once on first appear and cache for 15 minutes. Polling
//    more aggressively would burn battery for no perceptible gain on
//    a home-automation dashboard.
//  - Temperature is always in Fahrenheit with the `°F` suffix. Phase
//    3c can add a locale toggle; for now the Pencil mockup shows °F.
//  - The WMO weather-code → SF Symbol mapping covers the 20-ish
//    common codes. Anything exotic falls through to "cloud.fill".
//

import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class WeatherService: NSObject {
    /// The formatted headline string shown on the card, e.g. "68°F · Partly Cloudy".
    private(set) var headline: String = "Checking weather…"

    /// The suggestion line, e.g. "Perfect day to open the windows".
    private(set) var suggestion: String = ""

    /// SF Symbol name for the current condition.
    private(set) var iconName: String = "cloud.fill"

    /// True while we're actively fetching (first load only). The card
    /// shows a subtle shimmer while this is true.
    private(set) var isLoading: Bool = true

    @ObservationIgnored private var locationManager: CLLocationManager?
    @ObservationIgnored private var lastFetchDate: Date?
    @ObservationIgnored private let cacheDuration: TimeInterval = 15 * 60 // 15 min
    @ObservationIgnored private var lastTempUnit: String?

    /// Reads the user's temperature unit preference. Returns true for
    /// Fahrenheit, false for Celsius.
    private var useFahrenheit: Bool {
        (UserDefaults.standard.string(forKey: "appearance.tempUnit") ?? "celsius") != "celsius"
    }

    /// Kick off a weather fetch if we don't have a recent one cached,
    /// or if the temperature unit preference changed since the last fetch.
    func fetchIfNeeded() {
        let currentUnit = useFahrenheit ? "fahrenheit" : "celsius"
        let unitChanged = (lastTempUnit != nil && lastTempUnit != currentUnit)
        if !unitChanged, let last = lastFetchDate, Date().timeIntervalSince(last) < cacheDuration {
            return // cache still warm and unit unchanged
        }
        lastTempUnit = currentUnit
        startLocationRequest()
    }

    // MARK: - Location

    private func startLocationRequest() {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer // city-level is fine
        self.locationManager = manager

        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            // Denied or restricted — fall back to hardcoded placeholder
            // so the card still renders something useful.
            applyFallback()
        }
    }

    // MARK: - Fetch

    private func fetch(lat: Double, lon: Double) {
        let isFahrenheit = useFahrenheit
        let tempUnit = isFahrenheit ? "fahrenheit" : "celsius"
        let unitSuffix = isFahrenheit ? "°F" : "°C"
        Task {
            do {
                let url = URL(string:
                    "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code&temperature_unit=\(tempUnit)&timezone=auto"
                )!
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
                let temp = Int(response.current.temperature2m.rounded())
                let code = response.current.weatherCode
                let condition = conditionString(for: code)
                self.headline = "\(temp)\(unitSuffix) · \(condition)"
                self.iconName = sfSymbol(for: code)
                self.suggestion = makeSuggestion(tempF: isFahrenheit ? temp : Int(Double(temp) * 9.0 / 5.0 + 32), code: code)
                self.lastFetchDate = Date()
            } catch {
                applyFallback()
            }
            self.isLoading = false
        }
    }

    private func applyFallback() {
        // Stable fallback so the card is never empty. Uses a
        // time-of-day heuristic for the suggestion since we can't
        // read the actual forecast.
        self.headline = "Weather unavailable"
        self.suggestion = "Enable location for live weather"
        self.iconName = "cloud.fill"
        self.isLoading = false
    }

    // MARK: - WMO Code → UI

    private func conditionString(for code: Int) -> String {
        switch code {
        case 0:          return "Clear Sky"
        case 1:          return "Mainly Clear"
        case 2:          return "Partly Cloudy"
        case 3:          return "Overcast"
        case 45, 48:     return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 56, 57:     return "Freezing Drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67:     return "Freezing Rain"
        case 71, 73, 75: return "Snow"
        case 77:         return "Snow Grains"
        case 80, 81, 82: return "Rain Showers"
        case 85, 86:     return "Snow Showers"
        case 95:         return "Thunderstorm"
        case 96, 99:     return "Thunderstorm + Hail"
        default:         return "Cloudy"
        }
    }

    private func sfSymbol(for code: Int) -> String {
        switch code {
        case 0:              return "sun.max.fill"
        case 1:              return "sun.min.fill"
        case 2:              return "cloud.sun.fill"
        case 3:              return "cloud.fill"
        case 45, 48:         return "cloud.fog.fill"
        case 51, 53, 55:     return "cloud.drizzle.fill"
        case 56, 57:         return "cloud.sleet.fill"
        case 61, 63, 65:     return "cloud.rain.fill"
        case 66, 67:         return "cloud.sleet.fill"
        case 71, 73, 75, 77: return "cloud.snow.fill"
        case 80, 81, 82:     return "cloud.heavyrain.fill"
        case 85, 86:         return "cloud.snow.fill"
        case 95, 96, 99:     return "cloud.bolt.rain.fill"
        default:             return "cloud.fill"
        }
    }

    /// Suggestion thresholds are always in Fahrenheit so they work
    /// regardless of display unit. Callers convert to °F before passing.
    private func makeSuggestion(tempF temp: Int, code: Int) -> String {
        if code >= 95 { return "Severe weather — stay safe indoors" }
        if code >= 61 { return "Rainy — keep the windows closed" }
        if code >= 71 && code <= 77 { return "Snowy — bundle up if heading out" }
        if temp >= 85 { return "Hot outside — keep the AC running" }
        if temp >= 65 && temp < 85 && code <= 2 { return "Perfect day to open the windows" }
        if temp >= 50 && temp < 65 { return "Cool out — a light jacket might help" }
        if temp < 50 { return "Cold outside — keep things cozy" }
        return "Check conditions before heading out"
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        manager.stopUpdatingLocation()
        let lat = loc.coordinate.latitude
        let lon = loc.coordinate.longitude
        Task { @MainActor in
            self.fetch(lat: lat, lon: lon)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.applyFallback()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                self.applyFallback()
            default:
                break // still .notDetermined, waiting for user
            }
        }
    }
}

// MARK: - Open-Meteo response

private struct OpenMeteoResponse: Decodable {
    let current: Current

    struct Current: Decodable {
        let temperature2m: Double
        let weatherCode: Int

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case weatherCode = "weather_code"
        }
    }
}
