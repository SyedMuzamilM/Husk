import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AnalyzeView: View {
    @Bindable var model: AnalyzeViewModel
    @State private var selectedID: UUID?
    @State private var layout = "List"
    @State private var choosingFolder = false
    @State private var search = ""
    private var nodes: [DiskNode] {
        (model.current?.sortedChildren() ?? []).filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
    }
    private var selected: DiskNode? { nodes.first { $0.id == selectedID } }

    var body: some View {
        VStack(spacing: 0) {
            HuskPageHeader(title: "Storage Map", subtitle: "Find large folders using local file metadata.") {
                if model.isLoading { Button("Cancel") { model.cancel() } }
                Menu("Choose location", systemImage: "folder") {
                    Button("Choose folder…") { choosingFolder = true }
                    Button("Home folder") { model.scan(path: NSHomeDirectory()) }
                    Button("Library") { model.scan(path: NSHomeDirectory() + "/Library") }
                    Button("Downloads") { model.scan(path: NSHomeDirectory() + "/Downloads") }
                }.disabled(model.isBusy)
            }
            if let error = model.errorMessage { HuskNotice(message: error, systemImage: "exclamationmark.triangle").padding(.horizontal, HuskTheme.contentPadding) }
            if model.current == nil && !model.isLoading {
                ContentUnavailableView {
                    Label("Know where your space goes", systemImage: "chart.pie")
                } description: {
                    Text("Choose a local folder to see allocated sizes, then browse the list or storage map. Hidden items are included by default.")
                } actions: {
                    HuskPillButton(title: "Choose folder", systemImage: "folder") { choosingFolder = true }
                }
            } else { results }
        }
        .sheet(item: $model.removalPlan) { plan in
            RemovalReviewSheet(plan: plan) { frozen in Task { await model.trash(frozen); selectedID = nil } }
        }
        .sheet(item: $model.removalResult) { RemovalResultSheet(result: $0) }
        .onChange(of: model.isLoading) { _, loading in if loading { selectedID = nil } }
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url): model.scan(path: url.path)
            case .failure(let error): model.errorMessage = error.localizedDescription
            }
        }
    }

    private var results: some View {
        VStack(spacing: 14) {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(model.breadcrumbs) { node in
                        Button(node.name.isEmpty ? "Disk" : node.name) {
                            if let index = model.breadcrumbs.firstIndex(where: { $0.id == node.id }) { model.goToBreadcrumb(index: index); selectedID = nil }
                        }.buttonStyle(.borderless)
                        if node.id != model.breadcrumbs.last?.id { Image(systemName: "chevron.right").foregroundStyle(.secondary).accessibilityHidden(true) }
                    }
                }
            }
            HStack(spacing: 16) {
                HuskSearchField(prompt: "Filter folder contents", text: $search)
                Toggle("Hidden items", isOn: $model.includeHidden).onChange(of: model.includeHidden) { model.scan(path: model.current?.path ?? model.selectedRootPath) }
                Picker("View", selection: $layout) { Text("List").tag("List"); Text("Map").tag("Map") }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 130)
            }
            if let current = model.current {
                HStack {
                    Label(ByteFormat.string(for: current.byteCount), systemImage: "internaldrive").font(.headline)
                    Text("\(current.completeness.rawValue.capitalized) · Other/hidden \(ByteFormat.string(for: current.omittedBytes))").foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh", systemImage: "arrow.clockwise") { model.scan(path: current.path) }.disabled(model.isBusy)
                }
                if let issue = current.issues.first { HuskNotice(message: issue.message) }
            }
            if model.isLoading { ProgressView(model.statusText).frame(maxWidth: .infinity) }
            if layout == "List" {
                Table(nodes, selection: $selectedID) {
                    TableColumn("Name") { node in Label(node.name, systemImage: node.isDirectory ? "folder" : "doc").lineLimit(1) }
                    TableColumn("Allocated size") { node in Text(ByteFormat.string(for: node.byteCount)).monospacedDigit() }.width(130)
                    TableColumn("Coverage") { node in Text(node.completeness.rawValue.capitalized).foregroundStyle(.secondary) }.width(100)
                    TableColumn("Browse") { node in
                        if node.isDirectory { Button("Open", systemImage: "chevron.right") { model.drill(into: node) }.disabled(model.isBusy) }
                    }.width(80)
                }
                .frame(maxHeight: .infinity)
                .scrollContentBackground(.hidden)
                .background(Color.huskSurface.opacity(0.92), in: .rect(cornerRadius: HuskTheme.cardRadius))
                .clipShape(.rect(cornerRadius: HuskTheme.cardRadius))
                .contextMenu(forSelectionType: UUID.self) { ids in
                    if let node = nodes.first(where: { ids.contains($0.id) }) {
                        Button("Reveal in Finder") { model.reveal(node.path) }
                        Button("Exclude from scans") {
                            UserDefaults.standard.set(Array(Set(ScanPreferences.excludedPaths + [node.path])).sorted(), forKey: "husk.excludedPaths")
                            model.scan(path: model.current?.path)
                        }
                    }
                }
            } else {
                GeometryReader { geometry in
                    TreemapView(nodes: nodes, size: geometry.size, selectedID: selectedID,
                        onSelect: { selectedID = $0.nodeID },
                        onOpen: { rect in if let node = nodes.first(where: { $0.id == rect.nodeID }) { model.drill(into: node) } })
                }
            }
            if let selected { selectionBar(selected) }
            else { Text("Select a row to reveal its path or review removal. Sizes include shared APFS data and are estimates.").font(.callout).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
        }.padding(.horizontal, HuskTheme.contentPadding).padding(.bottom, HuskTheme.contentPadding)
    }

    private func selectionBar(_ node: DiskNode) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(node.name).font(.headline)
                Text(node.path).font(.body.monospaced()).lineLimit(2).truncationMode(.middle).textSelection(.enabled)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Button("Reveal", systemImage: "folder") { model.reveal(node.path) }
            HuskPillButton(title: "Review removal", systemImage: "trash") {
                Task { await model.prepareRemoval(path: node.path, bytes: node.byteCount) }
            }.disabled(model.isBusy || PathSafety.isProtected(node.path) || node.completeness == .unavailable)
        }.padding(14).background(Color.huskSurface, in: .rect(cornerRadius: HuskTheme.cardRadius))
    }
}
