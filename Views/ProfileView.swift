import SwiftUI

struct ProfileView: View {
    var body: some View {
        VStack {
            Text("User Profile")
                .font(.largeTitle)
                .foregroundColor(.white)

            Spacer()
        }
        .padding()
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}
