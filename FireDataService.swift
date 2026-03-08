import Foundation
import MapKit

struct FireHazardArea: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let severity: String
}

class FireDataService: ObservableObject {
    @Published var hazardAreas: [FireHazardArea] = []
    
    func fetchFireData() {
        // 这是一个公开的 CAL FIRE 相关的 GeoJSON 数据接口 (示例)
        let urlString = "https://gis.data.cnra.ca.gov/api/download/v1/items/e50b7577426c4367a518b80b38e9b5d8/geojson?layers=0"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                // TODO: 解析 GeoJSON 并更新 hazardAreas
                // 由于 GeoJSON 解析较复杂，初期我们可以先用 Mock 数据或简单的解析逻辑
                print("Successfully fetched fire data, length: \(data.count)")
            }
        }.resume()
    }
}
