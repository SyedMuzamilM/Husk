import SwiftUI

/// Fill the result viewport. Each pane must also accept the available height;
/// otherwise AppKit can shrink it to a table header beside an empty inspector.
struct HuskSplitView<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HSplitView(content: content).frame(maxHeight: .infinity)
    }
}
