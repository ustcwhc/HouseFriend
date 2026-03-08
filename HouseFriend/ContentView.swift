import SwiftUI
import MapKit

// 1. 定义图层枚举
enum MapLayer: String, CaseIterable, Identifiable {
    case fire = "Fire"
    case earthquake = "Earthquake"
    case crime = "Crime"
    case school = "School"
    case noise = "Noise"
    case population = "Population"
    case electric = "Electric Lines"
    case superfund = "Superfund"
    case supportive = "Supportive Home"
    case odor = "Milpitas Odor"
    
    var id: String { self.rawValue }
    var icon: String {
        switch self {
        case .fire: return "flame.fill"
        case .earthquake: return "waveform.path.ecg"
        case .crime: return "shield.fill"
        case .school: return "graduationcap.fill"
        case .noise: return "speaker.wave.3.fill"
        case .population: return "person.3.fill"
        case .electric: return "bolt.horizontal.fill"
        case .superfund: return "pills.fill"
        case .supportive: return "house.fill"
        case .odor: return "nose.fill"
        }
    }
}

// 2. 主视图
struct ContentView: View {
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
    ))
    
    @State private var activeLayers: Set<MapLayer> = [.fire, .earthquake]
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            // 使用 iOS 17+ 推荐的新版 Map 语法
            Map(position: ) {
                // 未来在这里添加 Annotation 或 MapPolygon
            }
            .edgesIgnoringSafeArea(.all)
            
            VStack {
                // 顶部标题
                HStack {
                    Text("🏡 HouseFriend")
                        .font(.title2)
                        .fontWeight(.heavy)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(15)
                    Spacer()
                    Button {
                        showSettings.toggle()
                    } label: {
                        Image(systemName: "layers.3.fill")
                            .font(.title2)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                Spacer()
                
                // 底部快捷切换
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(MapLayer.allCases) { layer in
                            Button {
                                if activeLayers.contains(layer) {
                                    activeLayers.remove(layer)
                                } else {
                                    activeLayers.insert(layer)
                                }
                            } label: {
                                Label(layer.rawValue, systemImage: layer.icon)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(activeLayers.contains(layer) ? layerColor(layer) : .secondary)
                            .clipShape(Capsule())
                        }
                    }
                    .padding()
                }
                .background(.ultraThinMaterial)
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

// 3. 设置页面
struct LayerSettingsView: View {
    @Binding var activeLayers: Set<MapLayer>
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List(MapLayer.allCases) { layer in
                Button {
                    if activeLayers.contains(layer) {
                        activeLayers.remove(layer)
                    } else {
                        activeLayers.insert(layer)
                    }
                } label: {
                    HStack {
                        Label(layer.rawValue, systemImage: layer.icon)
                            .foregroundColor(.primary)
                        Spacer()
                        if activeLayers.contains(layer) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Map Layers")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
