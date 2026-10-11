import SwiftUI

struct HuskPageHeader<Actions: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var actions: () -> Actions
    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 22, weight: .semibold)).accessibilityAddTraits(.isHeader)
                Text(subtitle).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            actions()
        }
        .padding(.horizontal, HuskTheme.contentPadding)
        .padding(.top, 16).padding(.bottom, 20)
    }
}

struct HuskSearchField: View {
    let prompt: String
    @Binding var text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
            TextField(prompt, text: $text).textFieldStyle(.plain)
            if !text.isEmpty {
                Button("Clear search", systemImage: "xmark.circle.fill") { text = "" }
                    .labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.huskSurfaceHigh.opacity(0.5), in: .rect(cornerRadius: 8))
    }
}

struct HuskNotice: View {
    let message: String
    var systemImage = "info.circle"
    var body: some View {
        Label { Text(message).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
            icon: { Image(systemName: systemImage) }
            .font(.callout).foregroundStyle(.secondary)
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.huskSurfaceHigh.opacity(0.45), in: .rect(cornerRadius: 8))
    }
}
