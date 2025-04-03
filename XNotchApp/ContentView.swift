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
                        ForEach(0..<10) { _ in
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
