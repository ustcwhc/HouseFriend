import SwiftUI

struct ZIPDemographicsSheet: View {
    let region: ZIPCodeRegion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ZIP \(region.id)")
                            .font(.title2).fontWeight(.bold)
                        Text(region.demographics.city)
                            .font(.subheadline).foregroundColor(.secondary)
                        HStack(spacing: 20) {
                            statBadge("Population", value: formatNum(region.demographics.totalPopulation))
                            statBadge("Median Age", value: "\(Int(region.demographics.medianAge))")
                            statBadge("Median Income", value: "$\(formatNum(region.demographics.medianHouseholdIncome))")
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal)

                    Divider()

                    // 1. Race / Ethnicity
                    sectionHeader("🧑‍🤝‍🧑 Race & Ethnicity")
                    raceStackedBar(region.demographics)
                        .padding(.horizontal)
                    raceLegend(region.demographics)
                        .padding(.horizontal)

                    Divider()

                    // 2. Household Income
                    sectionHeader("💰 Household Income")
                    incomeBarChart(region.demographics)
                        .padding(.horizontal)
                    HStack {
                        Text("Median: $\(formatNum(region.demographics.medianHouseholdIncome))/yr")
                            .font(.caption).foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)

                    Divider()

                    // 3. Age Distribution
                    sectionHeader("🎂 Age Distribution")
                    ageBarChart(region.demographics)
                        .padding(.horizontal)
                    HStack {
                        Text("Median Age: \(String(format: "%.1f", region.demographics.medianAge))")
                            .font(.caption).foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Race Stacked Bar

    func raceStackedBar(_ d: ZIPDemographics) -> some View {
        let items: [(String, Double, Color)] = [
            ("White",    d.white,    .blue),
            ("Hispanic", d.hispanic, Color.orange),
            ("Asian",    d.asian,    .green),
            ("Black",    d.black,    .purple),
            ("Other",    d.other,    .gray),
        ]
        return GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(items, id: \.0) { name, pct, color in
                    if pct >= 3 {
                        ZStack {
                            Rectangle().fill(color.opacity(0.85))
                            if pct >= 8 {
                                Text("\(Int(pct))%")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: geo.size.width * CGFloat(pct / 100))
                    }
                }
            }
            .frame(height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(height: 44)
    }

    func raceLegend(_ d: ZIPDemographics) -> some View {
        let items: [(String, Double, Color)] = [
            ("White \(Int(d.white))%",    d.white,    .blue),
            ("Hispanic \(Int(d.hispanic))%", d.hispanic, .orange),
            ("Asian \(Int(d.asian))%",    d.asian,    .green),
            ("Black \(Int(d.black))%",    d.black,    .purple),
            ("Other \(Int(d.other))%",    d.other,    .gray),
        ]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
            ForEach(items, id: \.0) { name, _, color in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.85))
                        .frame(width: 14, height: 14)
                    Text(name).font(.caption).foregroundColor(.primary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Income Bar Chart

    func incomeBarChart(_ d: ZIPDemographics) -> some View {
        let brackets: [(String, Double)] = [
            ("<$25k",    d.incomeUnder25k),
            ("$25-50k",  d.income25to50k),
            ("$50-75k",  d.income50to75k),
            ("$75-100k", d.income75to100k),
            ("$100-150k",d.income100to150k),
            ("$150k+",   d.incomeOver150k),
        ]
        let maxPct = brackets.map(\.1).max() ?? 1

        return VStack(spacing: 6) {
            ForEach(brackets, id: \.0) { label, pct in
                HStack(spacing: 8) {
                    Text(label)
                        .font(.caption2).foregroundColor(.secondary)
                        .frame(width: 70, alignment: .trailing)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.12))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(incomeColor(pct: pct, max: maxPct))
                                .frame(width: geo.size.width * CGFloat(pct / 100))
                        }
                    }
                    .frame(height: 22)
                    Text("\(Int(pct))%")
                        .font(.caption2).foregroundColor(.secondary)
                        .frame(width: 32, alignment: .leading)
                }
            }
        }
    }

    func incomeColor(pct: Double, max: Double) -> Color {
        let ratio = pct / max
        if ratio > 0.6 { return .green }
        if ratio > 0.35 { return .orange }
        return .red.opacity(0.8)
    }

    // MARK: - Age Bar Chart

    func ageBarChart(_ d: ZIPDemographics) -> some View {
        let groups: [(String, Double, Color)] = [
            ("0–17",  d.ageUnder18, Color(red: 0.2, green: 0.5, blue: 0.9)),
            ("18–34", d.age18to34,  Color(red: 0.1, green: 0.4, blue: 0.8)),
            ("35–54", d.age35to54,  Color(red: 0.1, green: 0.3, blue: 0.7)),
            ("55–64", d.age55to64,  Color(red: 0.1, green: 0.25, blue: 0.6)),
            ("65+",   d.age65plus,  Color(red: 0.1, green: 0.2, blue: 0.5)),
        ]
        let maxPct = groups.map(\.1).max() ?? 1

        return VStack(spacing: 6) {
            ForEach(groups, id: \.0) { label, pct, color in
                HStack(spacing: 8) {
                    Text(label)
                        .font(.caption2).foregroundColor(.secondary)
                        .frame(width: 38, alignment: .trailing)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.12))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(color)
                                .frame(width: geo.size.width * CGFloat(pct / maxPct))
                        }
                    }
                    .frame(height: 22)
                    let count = Int(Double(region.demographics.totalPopulation) * pct / 100)
                    Text("\(Int(pct))% · \(formatNum(count))")
                        .font(.caption2).foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Helpers

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal)
    }

    func statBadge(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline).fontWeight(.semibold)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }

    func formatNum(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000     { return String(format: "%.0fK", Double(n)/1_000) }
        return "\(n)"
    }
}
