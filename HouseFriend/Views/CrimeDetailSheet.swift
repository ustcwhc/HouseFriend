import SwiftUI

/// Bottom sheet listing crime incidents from a cluster or single marker tap.
struct CrimeDetailSheet: View {
    let crimes: [CrimeDetail]

    var body: some View {
        NavigationStack {
            if crimes.isEmpty {
                ContentUnavailableView(
                    "No Incidents",
                    systemImage: "shield.checkered",
                    description: Text("No crime incidents found in this area.")
                )
            }
            List(crimes) { crime in
                HStack(spacing: 12) {
                    Image(systemName: crime.severity.iconName)
                        .foregroundStyle(crime.severity.color)
                        .font(.title3)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(crime.category)
                            .font(.subheadline.bold())
                        if !crime.description.isEmpty {
                            Text(crime.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Text(crime.date)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .navigationTitle(crimes.count == 1 ? "Crime Incident" : "\(crimes.count) Crime Incidents")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}
