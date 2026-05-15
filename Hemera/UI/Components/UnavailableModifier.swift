import SwiftUI

struct UnavailableModifier: ViewModifier {
    let isAvailable: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isAvailable ? 1.0 : 0.45)
            .allowsHitTesting(isAvailable)
            .overlay(alignment: .topTrailing) {
                if !isAvailable {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
            }
    }
}

extension View {
    func unavailableStyle(_ isAvailable: Bool) -> some View {
        modifier(UnavailableModifier(isAvailable: isAvailable))
    }
}
