
import SwiftUI

struct ContentView: View {
    @State private var isMenuOpen = false
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Button(action: { isMenuOpen.toggle() }) {
                        Image(systemName: "line.horizontal.3")
                            .foregroundColor(.white)
                            .font(.title)
                    }
                    Spacer()
                    Text("XNotch")
                        .foregroundColor(.white)
                        .font(.title)
                        .bold()
                    Spacer()
                }
                .padding()
                
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        ForEach(0..<10) { index in
                            NotchCard()
                        }
                    }
                    .padding()
                }
            }
            
            if isMenuOpen {
                SideMenu(isOpen: $isMenuOpen)
            }
        }
    }
}

struct NotchCard: View {
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 150)
                .overlay(
                    Image(systemName: "camera.fill")
                        .foregroundColor(.white)
                        .font(.largeTitle)
                )
            
            Text("Dynamic Island Style")
                .foregroundColor(.white)
                .font(.subheadline)
                .padding(.top, 5)
        }
    }
}

struct SideMenu: View {
    @Binding var isOpen: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Menu")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding(.top, 50)
                
                Button("Home") {
                    // Action
                }
                
                Button("Favorites") {
                    // Action
                }
                
                Button("Settings") {
                    // Action
                }
                
                Spacer()
            }
            .frame(width: 250)
            .padding()
            .background(Color.gray.opacity(0.3))
            .edgesIgnoringSafeArea(.vertical)
            
            Spacer()
        }
    }
}

@main
struct XNotchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
