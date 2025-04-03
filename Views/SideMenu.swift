import SwiftUI

struct SideMenu: View {
    @Binding var isOpen: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Menu")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding(.top, 50)

                Button(action: { isOpen = false }) {
                    Text("Home").foregroundColor(.white)
                }

                Button(action: { isOpen = false }) {
                    Text("Favorites").foregroundColor(.white)
                }

                Button(action: { isOpen = false }) {
                    Text("Settings").foregroundColor(.white)
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
