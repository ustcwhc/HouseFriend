import SwiftUI

enum CategoryType: String, CaseIterable, Identifiable {
    case population = "Population"
    case crime = "Crime"
    case noise = "Noise"
    case electricLines = "Power Lines"
    case schools = "Schools"
    case superfund = "Superfund"
    case supportiveHome = "Group Homes"
    case milpitasOdor = "Air Quality"
    case earthquake = "Earthquake"
    case fireHazard = "Fire Risk"

    var id: String { rawValue }
}

struct NeighborhoodCategory: Identifiable {
    let id: CategoryType
    let name: String
    let icon: String
    let color: Color
    var score: Int?         // 0-100, nil = not loaded
    var scoreLabel: String? // e.g. "Low Risk", "A+", "Poor"

    static let all: [NeighborhoodCategory] = [
        NeighborhoodCategory(id: .population,     name: "Population",  icon: "person.3.fill",                   color: .blue),
        NeighborhoodCategory(id: .crime,          name: "Crime",       icon: "shield.fill",                     color: .red),
        NeighborhoodCategory(id: .noise,          name: "Noise",       icon: "speaker.wave.3.fill",             color: .orange),
        NeighborhoodCategory(id: .electricLines,  name: "Power Lines", icon: "bolt.fill",                      color: .yellow),
        NeighborhoodCategory(id: .schools,        name: "Schools",     icon: "graduationcap.fill",              color: .green),
        NeighborhoodCategory(id: .superfund,      name: "Superfund",   icon: "exclamationmark.triangle.fill",  color: .purple),
        NeighborhoodCategory(id: .supportiveHome, name: "Group Homes", icon: "house.and.flag.fill",            color: .teal),
        NeighborhoodCategory(id: .milpitasOdor,   name: "Air Quality", icon: "wind",                           color: .mint),
        NeighborhoodCategory(id: .earthquake,     name: "Earthquake",  icon: "waveform.path.ecg",              color: .brown),
        NeighborhoodCategory(id: .fireHazard,     name: "Fire Risk",   icon: "flame.fill",                     color: Color(red: 0.9, green: 0.3, blue: 0.1)),
    ]
}
