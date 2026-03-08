import SwiftUI

struct CategoryCardView: View {
    @Binding var category: NeighborhoodCategory
    var isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(category.color.opacity(isSelected ? 0.25 : 0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundColor(category.color)
            }

            Text(category.name)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 70)

            if let score = category.score {
                Text("\(score)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor(score))
            } else {
                ProgressView()
                    .scaleEffect(0.6)
            }

            if let label = category.scoreLabel {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 70)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? category.color.opacity(0.15) : Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(isSelected ? 0.15 : 0.06), radius: isSelected ? 6 : 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? category.color : Color.clear, lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60...79:  return .orange
        case 40...59:  return Color(red: 0.9, green: 0.5, blue: 0.0)
        default:       return .red
        }
    }
}
