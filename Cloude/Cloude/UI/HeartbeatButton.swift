//
//  HeartbeatButton.swift
//  Cloude
//

import SwiftUI

struct HeartbeatButton: View {
    let unreadCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.accentColor)
                    .padding(4)

                if unreadCount > 0 {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: -2)
                }
            }
        }
    }
}
