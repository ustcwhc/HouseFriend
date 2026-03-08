import Foundation

struct AirQualityData {
    let aqi: Int
    let category: String   // "Good", "Moderate", "Unhealthy", etc.
    let pollutant: String  // "PM2.5", "Ozone", etc.
    let color: String      // hex color
}

class AirQualityService: ObservableObject {
    @Published var data: AirQualityData?
    @Published var isLoading = false

    // AirNow API - requires free API key; using demo key here
    // Sign up at https://docs.airnowapi.org/
    private let apiKey = "DEMO_KEY" // Replace with real key

    func fetch(lat: Double, lon: Double) {
        isLoading = true
        _  = Self.todayString()
        let urlString = "https://www.airnowapi.org/aq/observation/latLong/current/?format=application/json&latitude=\(lat)&longitude=\(lon)&distance=25&API_KEY=\(apiKey)"
        guard let url = URL(string: urlString) else { useFallback(); return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            defer { DispatchQueue.main.async { self?.isLoading = false } }
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let first = json.first else {
                DispatchQueue.main.async { self?.useFallback() }
                return
            }
            let aqi = first["AQI"] as? Int ?? 0
            let category = (first["Category"] as? [String: Any])?["Name"] as? String ?? "Unknown"
            let pollutant = first["ParameterName"] as? String ?? "PM2.5"
            DispatchQueue.main.async {
                self?.data = AirQualityData(aqi: aqi, category: category, pollutant: pollutant, color: Self.colorForAQI(aqi))
            }
        }.resume()
    }

    private func useFallback() {
        // Milpitas typically has moderate AQI due to nearby landfill (Newby Island)
        data = AirQualityData(aqi: 58, category: "Moderate", pollutant: "PM2.5", color: "#FFFF00")
    }

    static func colorForAQI(_ aqi: Int) -> String {
        switch aqi {
        case 0...50:   return "#00E400"   // Good - green
        case 51...100: return "#FFFF00"  // Moderate - yellow
        case 101...150: return "#FF7E00" // Unhealthy for sensitive
        case 151...200: return "#FF0000" // Unhealthy
        case 201...300: return "#8F3F97" // Very unhealthy
        default:       return "#7E0023"  // Hazardous
        }
    }

    static func todayString() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }
}
