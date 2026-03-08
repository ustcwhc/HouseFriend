import SwiftUI

struct LegendView: View {
    let category: CategoryType

    var body: some View {
        Group {
            switch category {
            case .noise:      noiseLegend
            case .crime:      crimeLegend
            case .milpitasOdor: odorLegend
            case .electricLines: electricLegend
            default: EmptyView()
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .cornerRadius(10)
        .shadow(radius: 4)
    }

    var noiseLegend: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Noise:dB").font(.caption).fontWeight(.bold)
            ForEach([
                ("> 80",  Color(red: 0.3, green: 0.0, blue: 0.5)),
                ("70-80", Color(red: 0.6, green: 0.0, blue: 0.7)),
                ("65-70", Color(red: 0.9, green: 0.1, blue: 0.3)),
                ("60-65", Color(red: 1.0, green: 0.45, blue: 0.0)),
                ("55-60", Color(red: 1.0, green: 0.7, blue: 0.0)),
                ("50-55", Color(red: 1.0, green: 0.9, blue: 0.1)),
                ("50 <",  Color(red: 1.0, green: 1.0, blue: 0.4)),
            ], id: \.0) { label, color in
                legendRow(label: label, color: color)
            }
        }
    }

    var crimeLegend: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Crimes").font(.caption).fontWeight(.bold)
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color(red: 0.4, green: 0.0, blue: 0.0), Color.orange, Color(red: 1, green: 0.95, blue: 0.9)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(width: 20, height: 60)
                .cornerRadius(3)
            }
            .overlay(
                VStack {
                    Text("High").font(.system(size: 9)).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 26)
                    Spacer()
                    Text("Low").font(.system(size: 9)).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 26)
                }
            )
            .frame(height: 60)
        }
        .frame(width: 80)
    }

    var odorLegend: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Odor Risk").font(.caption).fontWeight(.bold)
            legendRow(label: "High",   color: Color(red: 1.0, green: 0.5, blue: 0.1))
            legendRow(label: "Medium", color: Color(red: 1.0, green: 0.8, blue: 0.3))
            legendRow(label: "Low",    color: Color(red: 0.5, green: 0.8, blue: 1.0))
        }
    }

    var electricLegend: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Transmission").font(.caption).fontWeight(.bold)
            legendRow(label: "≥ 115 kV", color: .purple)
            legendRow(label: "60-115 kV", color: Color(red: 0.7, green: 0.1, blue: 0.8))
            legendRow(label: "< 60 kV",  color: Color(red: 0.85, green: 0.5, blue: 0.9))
        }
    }

    func legendRow(label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 14, height: 14)
            Text(label).font(.system(size: 10))
        }
    }
}
