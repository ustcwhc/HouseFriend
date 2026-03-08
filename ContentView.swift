import SwiftUI
import MapKit

struct ContentView: View {
    // 默认定位到湾区 (San Francisco)
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )

    var body: some View {
        ZStack {
            Map(coordinateRegion: , showsUserLocation: true)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Text("HoodScout")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(10)
                    .padding(.top, 50)
                
                Spacer()
                
                HStack {
                    Button(action: {
                        // 未来在这里切换地震带图层
                    }) {
                        Label("Earthquake", systemImage: "waveform.path.ecg")
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        // 未来在这里切换火灾图层
                    }) {
                        Label("Fire", systemImage: "flame.fill")
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.bottom, 30)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
