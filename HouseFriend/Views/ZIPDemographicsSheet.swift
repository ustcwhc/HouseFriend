import SwiftUI

struct ZIPDemographicsSheet: View {
    let region: ZIPCodeRegion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // ── Header ──────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ZIP Code \(region.id)")
                            .font(.title2).fontWeight(.bold)
                        HStack(spacing: 12) {
                            statBadge("Population",
                                      value: formatNum(region.demographics.population))
                            statBadge("Median Age",
                                      value: "\(Int(region.demographics.medianAge))")
                            statBadge("Median Income",
                                      value: "$\(formatNum(region.demographics.medianIncome))")
                        }
                    }
                    .padding(.horizontal)

                    Divider()

                    // ── Race / Ethnicity ────────────────────────────────────
                    sectionHeader("🧑🏽‍🤝‍🧑🏻 Race & Ethnicity")
                    raceStackedBar(region.demographics)
                        .padding(.horizontal)
                    raceLegend(region.demographics)
                        .padding(.horizontal)

                    Divider()

                    // ── Household Income ────────────────────────────────────
                    sectionHeader("💰 Household Income")
                    incomeBarChart(region.demographics)
                        .padding(.horizontal)

                    Divider()

                    // ── Age Distribution ────────────────────────────────────
                    sectionHeader("🎂 Age Distribution")
                    ageBarChart(region.demographics)
                        .padding(.horizontal)

                    Spacer(minLength: 32)
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
            ("White",    Double(d.white),    .blue),
            ("Hispanic", Double(d.hispanic), .orange),
            ("Asian",    Double(d.asian),    .green),
            ("Black",    Double(d.black),    .purple),
            ("Other",    Double(d.other),    .gray),
        ]
        return GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(items, id: \.0) { _, pct, color in
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
        let items: [(String, Color)] = [
            ("White \(d.white)%",       .blue),
            ("Hispanic \(d.hispanic)%", .orange),
            ("Asian \(d.asian)%",       .green),
            ("Black \(d.black)%",       .purple),
            ("Other \(d.other)%",       .gray),
        ]
        return LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 6
        ) {
            ForEach(items, id: \.0) { name, color in
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
        let brackets: [(String, Int)] = [
            ("<$50k",     d.incUnder50),
            ("$50–100k",  d.inc50_100),
            ("$100–150k", d.inc100_150),
            ("$150–200k", d.inc150_200),
            ("$200k+",    d.inc200Plus),
        ]
        let maxPct = Double(brackets.map(\.1).max() ?? 1)

        return VStack(spacing: 6) {
            ForEach(brackets, id: \.0) { label, pct in
                HStack(spacing: 8) {
                    Text(label)
                        .font(.caption2).foregroundColor(.secondary)
                        .frame(width: 76, alignment: .trailing)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.12))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(incomeColor(pct: Double(pct), max: maxPct))
                                .frame(width: geo.size.width * CGFloat(Double(pct) / 100))
                        }
                    }
                    .frame(height: 22)
                    Text("\(pct)%")
                        .font(.caption2).foregroundColor(.secondary)
                        .frame(width: 30, alignment: .leading)
                }
            }
        }
    }

    func incomeColor(pct: Double, max: Double) -> Color {
        let ratio = pct / max
        if ratio > 0.6  { return .green }
        if ratio > 0.35 { return .orange }
        return .red.opacity(0.8)
    }

    // MARK: - Age Bar Chart

    func ageBarChart(_ d: ZIPDemographics) -> some View {
        let groups: [(String, Int, Color)] = [
            ("0–17",  d.age_under18, Color(red: 0.20, green: 0.55, blue: 0.90)),
            ("18–34", d.age_18_34,   Color(red: 0.10, green: 0.45, blue: 0.80)),
            ("35–54", d.age_35_54,   Color(red: 0.10, green: 0.35, blue: 0.70)),
            ("55–74", d.age_55_74,   Color(red: 0.10, green: 0.25, blue: 0.60)),
            ("75+",   d.age_75Plus,  Color(red: 0.10, green: 0.18, blue: 0.50)),
        ]
        let maxPct = Double(groups.map(\.1).max() ?? 1)

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
                                .frame(width: geo.size.width * CGFloat(Double(pct) / maxPct))
                        }
                    }
                    .frame(height: 22)
                    let count = Int(Double(d.population) * Double(pct) / 100)
                    Text("\(pct)% · \(formatNum(count))")
                        .font(.caption2).foregroundColor(.secondary)
                        .frame(width: 82, alignment: .leading)
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
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.0fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
