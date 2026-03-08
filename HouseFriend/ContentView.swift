import SwiftUI
import MapKit

struct ContentView: View {
    // 默认定位到旧金山湾区
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
    )
    
    @State private var activeLayers: Set<MapLayer> = [.fire, .earthquake]
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            // macOS 下的 Map 组件写法略有不同，我们用这种更通用的方式
            Map(coordinateRegion: , showsUserLocation: true)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                // Header
                HStack {
                    Text("🏡 HouseFriend")
                        .font(.title2)
                        .fontWeight(.heavy)
                        .padding()
                        .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
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
                .padding(.top, 20)
                
                Spacer()
                
                // Active Layer Indicators
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(MapLayer.allCases) { layer in
                            Button(action: {
                                if activeLayers.contains(layer) { activeLayers.remove(layer) }
                                else { activeLayers.insert(layer) }
                            }) {
                                Label(layer.rawValue, systemImage: layer.icon)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(activeLayers.contains(layer) ? layerColor(layer) : .secondary)
                            .clipShape(Capsule())
                        }
                    }
                    .padding()
                }
                .background(VisualEffectView(material: .contentBackground, blendingMode: .withinWindow))
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

// macOS 适配的毛玻璃效果
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct LayerSettingsView: View {
    @Binding var activeLayers: Set<MapLayer>
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            HStack {
                Text("Map Layers")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .padding()
            
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
        }
        .frame(width: 300, height: 400)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
