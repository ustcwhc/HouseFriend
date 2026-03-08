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

                Section("Ratings & Info") {
                    ratingRow("GreatSchools Rating", value: "\(school.rating)/10", color: ratingColor(school.rating))
                    ratingRow("Grade Level", value: school.level.fullName, color: .blue)
                    ratingRow("School District", value: school.district, color: .secondary)
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

                Section("Site Details") {
                    infoRow("Status", value: site.status, icon: "info.circle", valueColor: statusColor)
                    infoRow("Risk Level", value: riskLabel, icon: "exclamationmark.triangle.fill", valueColor: severityColor)
                    if let dist = site.distanceMiles {
                        infoRow("Distance", value: String(format: "%.1f mi from pin", dist), icon: "ruler", valueColor: severityColor)
                    }
                }

                Section("Primary Contaminants") {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "atom")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(site.contaminants.components(separatedBy: ","), id: \.self) { c in
                                HStack(spacing: 6) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 5))
                                        .foregroundColor(.orange)
                                    Text(c.trimmingCharacters(in: .whitespaces))
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("About Superfund Sites") {
                    Text("EPA Superfund sites are locations contaminated with hazardous substances that pose risks to public health or the environment. The EPA's National Priorities List (NPL) identifies sites requiring long-term cleanup action.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button {
                        let query = site.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        let url = URL(string: "https://www.epa.gov/superfund/search-superfund-sites-where-you-live#results?query=\(query)") ?? URL(string: "https://www.epa.gov/superfund")!
                        UIApplication.shared.open(url)
                    } label: {
                        Label("Search on EPA Superfund", systemImage: "globe")
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

    var statusColor: Color {
        switch site.status {
        case "NPL":      return .red
        case "Proposed": return .orange
        case "Deleted":  return .green
        case "Active":   return .orange
        default:         return .secondary
        }
    }

    var riskLabel: String {
        guard let d = site.distanceMiles else { return "Unknown" }
        return d < 1 ? "High — Very Close" : d < 3 ? "Moderate" : "Low — Far Away"
    }

    func infoRow(_ label: String, value: String, icon: String, valueColor: Color = .secondary) -> some View {
        HStack {
            Label(label, systemImage: icon).foregroundColor(.primary)
            Spacer()
            Text(value).foregroundColor(valueColor).font(.subheadline).fontWeight(.medium)
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
                        Text(facility.type)
                            .foregroundColor(typeColor)
                            .fontWeight(.medium)
                    }
                    if let cap = facility.capacity {
                        HStack {
                            Label("Capacity", systemImage: "person.3.fill")
                            Spacer()
                            Text("~\(cap) beds/units").foregroundColor(.secondary)
                        }
                    }
                }

                Section("About") {
                    Text(typeDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
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

    var typeColor: Color {
        switch facility.type {
        case "Shelter":      return .red
        case "Transitional": return .orange
        case "Permanent":    return .green
        default:             return .secondary
        }
    }

    var typeDescription: String {
        switch facility.type {
        case "Shelter":
            return "Emergency shelters provide immediate, short-term housing for people experiencing homelessness. Services typically include meals, case management, and referrals."
        case "Transitional":
            return "Transitional housing provides temporary housing (typically 6-24 months) with support services to help residents move toward permanent housing."
        case "Permanent":
            return "Permanent supportive housing provides long-term affordable housing combined with support services for individuals and families with special needs."
        default:
            return "This facility provides housing support services for community members in need."
        }
    }
}
