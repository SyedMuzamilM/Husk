import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AnalyzeView: View {
    @Bindable var model: AnalyzeViewModel
    @Bindable var cleanup: CleanViewModel
    @State private var selectedID: UUID?
    @State private var layout = "Map"
    @State private var colorMode: StorageMapColorMode = .category
    @State private var choosingFolder = false
    @State private var search = ""
    @State private var recommendation: CleanItem?

    private var nodes: [DiskNode] {
        (model.current?.mapChildren ?? []).sorted { $0.byteCount > $1.byteCount }
            .filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
    }
    private var selected: DiskNode? {
        for node in nodes {
            if node.id == selectedID { return node }
            if let child = node.mapChildren.first(where: { $0.id == selectedID }) { return child }
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HuskPageHeader(title: "Storage Map", subtitle: "See what fills your Mac. Review cleanup in one place.") {
                if model.isLoading { Button("Cancel") { model.cancel() } }
                Menu("Choose location", systemImage: "folder") {
                    Button("Startup disk overview") { model.scan(path: "/") }
                    Button("Home folder") { model.scan(path: NSHomeDirectory()) }
                    Button("Library") { model.scan(path: NSHomeDirectory() + "/Library") }
                    Button("Downloads") { model.scan(path: NSHomeDirectory() + "/Downloads") }
                    Button("Choose folder…") { choosingFolder = true }
                }.disabled(model.isBusy)
            }
            if let error = model.errorMessage ?? cleanup.removalError {
                HuskNotice(message: error, systemImage: "exclamationmark.triangle").padding(.horizontal, HuskTheme.contentPadding).padding(.bottom, 10)
            }
            VStack(spacing: 14) {
                StorageSummaryView(capacity: model.capacity, summary: cleanup.storageSummary,
                    measuredBytes: mappedBytes, hasCleanupScan: !cleanup.categories.isEmpty || cleanup.lastResult != nil)
                HStack(alignment: .top, spacing: 14) {
                    explorer.frame(maxWidth: .infinity, maxHeight: .infinity)
                    StorageRecommendationsView(model: cleanup) { item in
                        cleanup.inspect(item); recommendation = item
                    }.frame(minWidth: 285, idealWidth: 310, maxWidth: 340, maxHeight: .infinity)
                        .disabled(model.isPreparing || model.isRemoving)
                }.frame(maxHeight: .infinity)
            }.padding(.horizontal, HuskTheme.contentPadding).padding(.bottom, HuskTheme.contentPadding)
        }
        .sheet(item: $model.removalPlan) { plan in
            RemovalReviewSheet(plan: plan) { frozen in Task { await model.trash(frozen); selectedID = nil } }
        }
        .sheet(item: $model.removalResult) { RemovalResultSheet(result: $0) }
        .sheet(item: $cleanup.removalPlan) { plan in
            RemovalReviewSheet(plan: plan) { frozen in Task { await cleanup.moveSelectionToTrash(frozen) } }
        }
        .sheet(item: $cleanup.removalResult) { RemovalResultSheet(result: $0) }
        .sheet(item: $recommendation, onDismiss: { cleanup.clearInspection() }) { item in
            VStack(spacing: 0) {
                HStack {
                    Button("Show in map", systemImage: "map") { recommendation = nil; model.scan(path: item.url.deletingLastPathComponent().path) }
                        .disabled(model.isBusy)
                    Spacer()
                    Button("Done") { recommendation = nil }.keyboardShortcut(.cancelAction)
                }.padding(16)
                Divider()
                CacheDetailPanel(item: item, report: cleanup.cacheDetail, isLoading: cleanup.isLoadingDetail,
                    onReveal: model.reveal, onToggleSelect: { cleanup.toggle(item) }, isSelected: cleanup.selectedIDs.contains(item.id))
            }.frame(width: 520, height: 560)
        }
        .onChange(of: model.isLoading) { _, loading in if loading { selectedID = nil } }
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url): model.scan(path: url.path)
            case .failure(let error): model.errorMessage = error.localizedDescription
            }
        }
    }

    private var mappedBytes: Int64? {
        guard let current = model.current else { return nil }
        return current.path == "/" ? current.children.filter { !$0.isAggregate }.reduce(0) { $0 + $1.byteCount } : current.byteCount
    }

    private var explorer: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Explorer").font(.headline)
                    Text("Double-click folders to explore.").font(.callout).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Picker("Map colors", selection: $colorMode) {
                    ForEach(StorageMapColorMode.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).frame(width: 158).labelsHidden()
            }.padding(16)
            Divider()
            if model.current == nil && !model.isLoading {
                ContentUnavailableView {
                    Label("Know where your space goes", systemImage: "chart.pie")
                } description: { Text("Map your home folder, browse a startup disk overview, or choose a local folder. Hidden items are included.") }
                  actions: {
                    Button("Map home folder") { model.scan(path: NSHomeDirectory()) }
                    Button("Choose folder") { choosingFolder = true }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                results
            }
        }
        .background(Color.huskSurface, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.huskBorder))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var results: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ScrollView(.horizontal) {
                    HStack(spacing: 5) {
                        ForEach(model.breadcrumbs) { node in
                            Button(node.name.isEmpty ? "Disk" : node.name) {
                                if let index = model.breadcrumbs.firstIndex(where: { $0.id == node.id }) { model.goToBreadcrumb(index: index); selectedID = nil }
                            }.buttonStyle(.borderless)
                            if node.id != model.breadcrumbs.last?.id { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary).accessibilityHidden(true) }
                        }
                    }
                }.scrollIndicators(.hidden)
                if let current = model.current {
                    Text(ByteFormat.string(for: current.byteCount)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    if current.completeness != .complete { Text("Partial").font(.caption).foregroundStyle(Color.reviewLabel) }
                }
                Button("Refresh", systemImage: "arrow.clockwise") { model.scan(path: model.current?.path) }.labelStyle(.iconOnly).disabled(model.isBusy)
            }
            HStack(spacing: 10) {
                TextField("Filter contents", text: $search).textFieldStyle(.roundedBorder).accessibilityLabel("Filter folder contents")
                Toggle("Hidden", isOn: $model.includeHidden).disabled(model.isBusy).onChange(of: model.includeHidden) { model.scan(path: model.current?.path ?? model.selectedRootPath) }
                Picker("View", selection: $layout) { Text("List").tag("List"); Text("Map").tag("Map") }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 105)
            }.controlSize(.small)
            if model.isLoading { ProgressView(model.statusText).frame(maxWidth: .infinity) }
            if nodes.isEmpty && !model.isLoading {
                ContentUnavailableView.search(text: search).frame(maxHeight: .infinity)
            } else if layout == "List" {
                folderTable
            } else {
                GeometryReader { geometry in
                    TreemapView(nodes: nodes, size: geometry.size, selectedID: selectedID, colorMode: colorMode,
                        summary: cleanup.storageSummary, onSelect: { selectedID = $0.id }, onOpen: { model.drill(into: $0) })
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            legend
            Divider()
            if let selected { selectionBar(selected) }
            else {
                Text(model.current?.issues.first?.message ?? "Bounded previews. Refresh after cleanup. APFS shared blocks and Trash retention affect reclaimed space.")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(14).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var folderTable: some View {
        Table(nodes, selection: $selectedID) {
            TableColumn("Name") { node in Label(node.name, systemImage: node.isAggregate ? "square.dashed" : node.isDirectory ? "folder" : "doc").lineLimit(1) }
            TableColumn("Allocated size") { node in Text(ByteFormat.string(for: node.byteCount)).monospacedDigit() }.width(100)
            TableColumn("Browse") { node in
                if node.isDirectory && !node.isAggregate { Button("Open", systemImage: "chevron.right") { model.drill(into: node) }.disabled(model.isBusy) }
            }.width(65)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).scrollContentBackground(.hidden)
        .contextMenu(forSelectionType: UUID.self) { ids in
            if let node = nodes.first(where: { ids.contains($0.id) }), !node.isAggregate {
                Button("Reveal in Finder") { model.reveal(node.path) }
                Button("Exclude from scans") {
                    UserDefaults.standard.set(Array(Set(ScanPreferences.excludedPaths + [node.path])).sorted(), forKey: "husk.excludedPaths")
                    model.scan(path: model.current?.path)
                }
            }
        }
    }

    private var legend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { legendLabels }
            ScrollView(.horizontal) { HStack(spacing: 10) { legendLabels } }.scrollIndicators(.hidden)
        }.frame(height: 18)
    }

    @ViewBuilder private var legendLabels: some View {
        if colorMode == .category {
            ForEach(StorageCategory.allCases) { category in
                Label { Text(category.title) } icon: { RoundedRectangle(cornerRadius: 1).fill(category.color).frame(width: 6, height: 6) }
                    .font(.caption).foregroundStyle(.secondary).fixedSize()
            }
        } else {
            ForEach(SafetyLabel.allCases, id: \.self) { safety in
                Label { Text(safety.title) } icon: { Circle().fill(safety.color).frame(width: 6, height: 6) }.font(.caption).foregroundStyle(.secondary)
            }
            Text("Gray also includes unclassified storage").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func selectionBar(_ node: DiskNode) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(node.name).font(.callout.weight(.medium))
                Text(node.isAggregate ? "Aggregate estimate. No removal target." : node.path)
                    .font(.caption.monospaced()).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
            }.frame(maxWidth: .infinity, alignment: .leading)
            if !node.isAggregate {
                Button("Reveal") { model.reveal(node.path) }
                Button("Review removal") { Task { await model.prepareRemoval(path: node.path, bytes: node.byteCount) } }
                    .disabled(model.isBusy || cleanup.isBusy || PathSafety.isProtected(node.path) || node.completeness == .unavailable)
            }
        }.controlSize(.small)
    }
}
