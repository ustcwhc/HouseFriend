import Foundation
import MapKit

enum MapLayer: String, CaseIterable, Identifiable {
    case fire = "Fire"
    case earthquake = "Earthquake"
    case crime = "Crime"
    case school = "School"
    case noise = "Noise"
    case population = "Population"
    case electric = "Electric Lines"
    case superfund = "Superfund"
    case supportive = "Supportive Home"
    case odor = "Milpitas Odor"
    
    var id: String { self.rawValue }
    var icon: String {
        switch self {
        case .fire: return "flame.fill"
        case .earthquake: return "waveform.path.ecg"
        case .crime: return "shield.fill"
        case .school: return "graduationcap.fill"
        case .noise: return "speaker.wave.3.fill"
        case .population: return "person.3.fill"
        case .electric: return "bolt.horizontal.fill"
        case .superfund: return "pills.fill"
        case .supportive: return "house.fill"
        case .odor: return "nose.fill"
        }
    }
}

struct MapFeature: Identifiable {
    let id = UUID()
    let name: String
    let type: MapLayer
    let coordinate: CLLocationCoordinate2D
}
