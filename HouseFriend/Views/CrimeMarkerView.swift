import SwiftUI

struct CrimeMarkerView: View {
    let marker: CrimeMarker

    var body: some View {
        ZStack {
            if marker.type == .violent {
                Image(systemName: "star.fill")
                    .font(.system(size: 28))
                    .foregroundColor(marker.type.markerColor)
                    .overlay(
                        Image(systemName: marker.type.systemImage)
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                    )
            } else if marker.count > 1 {
                Circle()
                    .fill(Color(UIColor.systemBackground))
                    .frame(width: 28, height: 28)
                    .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.15), radius: 2)
                    .overlay(
                        Text("\(marker.count)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                    )
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(marker.type.markerColor)
                        .frame(width: 32, height: 32)
                    Image(systemName: marker.type.systemImage)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
                .shadow(color: .black.opacity(0.2), radius: 3)
            }
        }
    }
}
