//
//  HeartbeatButton.swift
//  Cloude
//

import SwiftUI

struct HeartbeatButton: View {
    let unreadCount: Int
    let action: () -> Void
    @State private var isPulsing = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.accentColor)
                    .scaleEffect(isPulsing ? 1.15 : 1.0)
                    .padding(4)

                if unreadCount > 0 {
                    Text(unreadCount > 9 ? "9+" : "\(unreadCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .frame(minWidth: 14, minHeight: 14)
                        .background(Circle().fill(.red))
                        .offset(x: 4, y: -4)
                }
            }
        }
        .onChange(of: unreadCount) { oldValue, newValue in
            if newValue > oldValue {
                withAnimation(.easeInOut(duration: 0.15).repeatCount(3, autoreverses: true)) {
                    isPulsing = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isPulsing = false
                }
            }
        }
    }
}
