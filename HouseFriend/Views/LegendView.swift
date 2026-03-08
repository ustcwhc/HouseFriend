import SwiftUI

struct LegendView: View {
    let category: CategoryType

    var body: some View {
        Group {
            switch category {
            case .noise:       noiseLegend
            case .crime:       crimeLegend
            case .milpitasOdor: odorLegend
            case .electricLines: electricLegend
            case .fireHazard:  fireLegend
            case .earthquake:  earthquakeLegend
            case .schools:     schoolLegend
            case .superfund:   superfundLegend
            default: EmptyView()
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .cornerRadius(10)
        .shadow(radius: 3)
    }

    var noiseLegend: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Noise (dB)").font(.caption2).fontWeight(.bold)
            ForEach([
                ("> 80 dB",  Color(red: 0.28, green: 0.0, blue: 0.50)),
                ("70-80",    Color(red: 0.60, green: 0.0, blue: 0.72)),
                ("65-70",    Color(red: 0.92, green: 0.1, blue: 0.3)),
                ("60-65",    Color(red: 1.0,  green: 0.45, blue: 0.0)),
                ("55-60",    Color(red: 1.0,  green: 0.72, blue: 0.0)),
                ("< 55 dB",  Color(red: 1.0,  green: 1.0,  blue: 0.4)),
            ], id: \.0) { row(label: $0, color: $1) }
        }
    }

    var crimeLegend: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Crime Rate").font(.caption2).fontWeight(.bold)
            row(label: "High",     color: Color(red: 1.0, green: 0.0, blue: 0.0))
            row(label: "Moderate", color: Color(red: 1.0, green: 0.5, blue: 0.0))
            row(label: "Low",      color: Color(red: 0.2, green: 0.7, blue: 0.0))
        }
    }

    var odorLegend: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Odor Risk").font(.caption2).fontWeight(.bold)
            row(label: "High (Newby Island)",  color: Color(red: 1.0, green: 0.5, blue: 0.1))
            row(label: "Medium",               color: Color(red: 1.0, green: 0.8, blue: 0.3))
            row(label: "Low",                  color: Color(red: 0.5, green: 0.8, blue: 1.0))
        }
    }

    var electricLegend: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Transmission Lines").font(.caption2).fontWeight(.bold)
            HStack(spacing: 5) { lineBox(.purple); Text("≥ 115 kV").font(.system(size: 10)) }
            HStack(spacing: 5) { lineBox(Color(red:0.7,green:0.1,blue:0.8)); Text("60-115 kV").font(.system(size: 10)) }
            HStack(spacing: 5) { lineBox(Color(red:0.85,green:0.5,blue:0.9)); Text("< 60 kV").font(.system(size: 10)) }
        }
    }

    var fireLegend: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Fire Hazard (CAL FIRE)").font(.caption2).fontWeight(.bold)
            row(label: "Extreme",   color: Color(red: 0.85, green: 0.0, blue: 0.0))
            row(label: "Very High", color: Color(red: 0.95, green: 0.35, blue: 0.0))
            row(label: "High",      color: Color(red: 1.0,  green: 0.65, blue: 0.0))
        }
    }

    var earthquakeLegend: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Magnitude (USGS)").font(.caption2).fontWeight(.bold)
            row(label: "M ≥ 5.0",  color: .red)
            row(label: "M 4.0-4.9", color: .orange)
            row(label: "M 2.5-3.9", color: Color(red: 1.0, green: 0.75, blue: 0.0))
        }
    }

    var schoolLegend: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Schools").font(.caption2).fontWeight(.bold)
            HStack(spacing: 5) { colorBox(.green);  Text("E – Elementary").font(.system(size: 10)) }
            HStack(spacing: 5) { colorBox(.blue);   Text("M – Middle").font(.system(size: 10)) }
            HStack(spacing: 5) { colorBox(Color(red:0.4,green:0,blue:0.7)); Text("H – High").font(.system(size: 10)) }
            Text("(#) = GreatSchools Rating").font(.system(size: 9)).foregroundColor(.secondary)
        }
    }

    var superfundLegend: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Superfund Sites (EPA)").font(.caption2).fontWeight(.bold)
            HStack(spacing: 5) { Image(systemName: "flask.fill").foregroundColor(.red).font(.caption);    Text("< 1 mile").font(.system(size: 10)) }
            HStack(spacing: 5) { Image(systemName: "flask.fill").foregroundColor(.orange).font(.caption); Text("1-3 miles").font(.system(size: 10)) }
            HStack(spacing: 5) { Image(systemName: "flask.fill").foregroundColor(.green).font(.caption);  Text("> 3 miles").font(.system(size: 10)) }
        }
    }

    func row(label: String, color: Color) -> some View {
        HStack(spacing: 5) { colorBox(color); Text(label).font(.system(size: 10)) }
    }

    func colorBox(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 14, height: 14)
    }

    func lineBox(_ color: Color) -> some View {
        Rectangle().fill(color).frame(width: 20, height: 3).cornerRadius(1.5)
    }
}
