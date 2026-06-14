import SwiftUI

extension View {
    func neumorphicCard(radius: CGFloat = 16) -> some View {
        self
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .shadow(color: .white.opacity(0.8), radius: 6, x: -4, y: -4)
            .shadow(color: Color(.systemGray4), radius: 6, x: 4, y: 4)
    }
}
