//
//  ToolbarHoverButton.swift
//  Curtain
//
//  Created by Toan Phung on 01/02/2026.
//

import SwiftUI

/// A button that shows a tooltip label on hover (macOS Catalyst).
struct ToolbarHoverButton: View {
    let icon: String
    let label: String
    var disabled: Bool = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1.0)
        .overlay(alignment: .top) {
            if isHovering {
                Text(label)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
                    .fixedSize()
                    .offset(y: -28)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
