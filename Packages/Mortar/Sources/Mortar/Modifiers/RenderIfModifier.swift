import SwiftUI

extension View {
    @ViewBuilder
    public func renderIf(_ condition: Bool) -> some View {
        if condition {
            self
        }
    }
}
