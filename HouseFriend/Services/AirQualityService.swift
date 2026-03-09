import Foundation

struct AirQualityData {
    let aqi: Int
    let category: String
    let pollutant: String
}

class AirQualityService: ObservableObject {
    @Published var data: AirQualityData?
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Uses Open-Meteo Air Quality API — completely free, no API key needed
    func fetch(lat: Double, lon: Double) {
        isLoading = true
        errorMessage = nil
        let urlString = "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=\(lat)&longitude=\(lon)&current=us_aqi,pm2_5,european_aqi"
        guard let url = URL(string: urlString) else { useFallback(); return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            defer { DispatchQueue.main.async { self?.isLoading = false } }
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current"] as? [String: Any],
                  let aqi = current["us_aqi"] as? Int else {
                DispatchQueue.main.async {
                    self?.errorMessage = "Air quality data unavailable, using estimate"
                    self?.useFallback()
                }
                return
            }
            DispatchQueue.main.async {
                self?.data = AirQualityData(
                    aqi: aqi,
                    category: Self.categoryForAQI(aqi),
                    pollutant: "PM2.5"
                )
            }
        }.resume()
    }

    private func useFallback() {
        // Bay Area typical moderate AQI
        data = AirQualityData(aqi: 52, category: "Moderate", pollutant: "PM2.5")
    }

    static func categoryForAQI(_ aqi: Int) -> String {
        switch aqi {
        case 0...50:   return "Good"
        case 51...100: return "Moderate"
        case 101...150: return "Unhealthy for Sensitive Groups"
        case 151...200: return "Unhealthy"
        case 201...300: return "Very Unhealthy"
        default:       return "Hazardous"
        }
    }
}
