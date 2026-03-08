import SwiftUI
import MapKit

struct ContentView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
    )
    
    @State private var activeLayers: Set<MapLayer> = [.fire, .earthquake]
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: , showsUserLocation: true)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                // Header
                HStack {
                    Text("🏡 HouseFriend")
                        .font(.title2)
                        .fontWeight(.heavy)
                        .padding()
                        .background(BlurView(style: .systemMaterial))
                        .cornerRadius(15)
                        .shadow(radius: 5)
                    Spacer()
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "layers.3.fill")
                            .font(.title2)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 50)
                
                Spacer()
                
                // Active Layer Indicators
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(MapLayer.allCases) { layer in
                            Toggle(isOn: Binding(
                                get: { activeLayers.contains(layer) },
                                set: { isOn in
                                    if isOn { activeLayers.insert(layer) }
                                    else { activeLayers.remove(layer) }
                                }
                            )) {
                                Label(layer.rawValue, systemImage: layer.icon)
                            }
                            .toggleStyle(.button)
                            .buttonStyle(.borderedProminent)
                            .tint(activeLayers.contains(layer) ? layerColor(layer) : .gray)
                            .clipShape(Capsule())
                        }
                    }
                    .padding()
                }
                .background(BlurView(style: .systemUltraThinMaterial))
            }
        }
        .sheet(isPresented: ) {
            LayerSettingsView(activeLayers: )
        }
    }
    
    func layerColor(_ layer: MapLayer) -> Color {
        switch layer {
        case .fire: return .red
        case .earthquake: return .orange
        case .crime: return .purple
        case .school: return .blue
        case .noise: return .yellow
        default: return .green
        }
    }
}

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

struct LayerSettingsView: View {
    @Binding var activeLayers: Set<MapLayer>
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List(MapLayer.allCases) { layer in
                HStack {
                    Label(layer.rawValue, systemImage: layer.icon)
                    Spacer()
                    if activeLayers.contains(layer) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if activeLayers.contains(layer) { activeLayers.remove(layer) }
                    else { activeLayers.insert(layer) }
                }
            }
            .navigationTitle("Map Layers")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
