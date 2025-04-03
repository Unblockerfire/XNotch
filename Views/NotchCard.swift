import SwiftUI

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
