import SwiftUI
import MapKit

// MARK: - School Detail
struct SchoolDetailSheet: View {
    let school: School
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        SchoolMarkerView(school: school)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(school.name).font(.headline)
                            Text(school.level.fullName).font(.subheadline).foregroundColor(.secondary)
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.vertical, 4)
                }

                Section("Ratings") {
                    ratingRow("GreatSchools Rating", value: "\(school.rating)/10", color: ratingColor(school.rating))
                    ratingRow("Grade Level", value: school.level.fullName, color: .blue)
                }

                Section("Location") {
                    HStack {
                        Image(systemName: "map").foregroundColor(.gray)
                        Text(String(format: "%.4f, %.4f", school.coordinate.latitude, school.coordinate.longitude))
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Button {
                        let placemark = MKPlacemark(coordinate: school.coordinate)
                        let item = MKMapItem(placemark: placemark)
                        item.name = school.name
                        item.openInMaps()
                    } label: {
                        Label("Open in Maps", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                    }
                }
            }
            .navigationTitle(school.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    func ratingRow(_ label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).foregroundColor(.primary)
            Spacer()
            Text(value).fontWeight(.semibold).foregroundColor(color)
        }
    }

    func ratingColor(_ r: Int) -> Color {
        r >= 8 ? .green : r >= 6 ? .orange : .red
    }
}

extension SchoolLevel {
    var fullName: String {
        switch self {
        case .elementary: return "Elementary School"
        case .middle:     return "Middle School"
        case .high:       return "High School"
        }
    }
}

// MARK: - Superfund Detail
struct SuperfundDetailSheet: View {
    let site: SuperfundSite
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "flask.fill")
                            .font(.largeTitle)
                            .foregroundColor(severityColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(site.name).font(.headline)
                            Text(site.status).font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Details") {
                    infoRow("Status", value: site.status, icon: "info.circle")
                    if let dist = site.distanceMiles {
                        infoRow("Distance", value: String(format: "%.1f miles from pin", dist), icon: "ruler")
                    }
                    infoRow("Risk Level", value: riskLabel, icon: "exclamationmark.triangle")
                }

                Section("About Superfund Sites") {
                    Text("EPA Superfund sites are locations contaminated with hazardous substances. The EPA works to clean up these sites to protect human health and the environment.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button {
                        if let url = URL(string: "https://www.epa.gov/superfund") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("View EPA Superfund Info", systemImage: "globe")
                    }
                }
            }
            .navigationTitle("Superfund Site")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    var severityColor: Color {
        guard let d = site.distanceMiles else { return .orange }
        return d < 1 ? .red : d < 3 ? .orange : .green
    }

    var riskLabel: String {
        guard let d = site.distanceMiles else { return "Unknown" }
        return d < 1 ? "High — Very Close" : d < 3 ? "Moderate" : "Low — Far Away"
    }

    func infoRow(_ label: String, value: String, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon).foregroundColor(.primary)
            Spacer()
            Text(value).foregroundColor(.secondary).font(.subheadline)
        }
    }
}

// MARK: - Housing Detail
struct HousingDetailSheet: View {
    let facility: SupportiveHousingFacility
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "house.fill")
                            .font(.largeTitle)
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(facility.name.replacingOccurrences(of: "\n", with: " "))
                                .font(.headline)
                            Text(facility.type).font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Details") {
                    HStack {
                        Label("Type", systemImage: "house.and.flag")
                        Spacer()
                        Text(facility.type).foregroundColor(.secondary)
                    }
                }

                Section {
                    Button {
                        let placemark = MKPlacemark(coordinate: facility.coordinate)
                        let item = MKMapItem(placemark: placemark)
                        item.name = facility.name.replacingOccurrences(of: "\n", with: " ")
                        item.openInMaps()
                    } label: {
                        Label("Open in Maps", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                    }
                }
            }
            .navigationTitle("Supportive Housing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
