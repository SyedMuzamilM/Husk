//
//  AnalyzeView.swift
//  Husk
//

import AppKit
import SwiftUI

struct AnalyzeView: View {
    @Bindable var model: AnalyzeViewModel
    @State private var selectedRect: TreemapRect?
    @State private var confirmTrashPath: String?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            breadcrumbsBar
            Divider()

            GeometryReader { geo in
                ZStack {
                    if model.isLoading && model.current == nil {
                        ProgressView("Mapping disk…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let current = model.current {
                        let children = current.sortedChildren()
                        if children.isEmpty {
                            EmptyStateView(
                                systemImage: "folder",
                                title: "Empty folder",
                                message: current.path
                            )
                        } else {
                            TreemapView(
                                nodes: children,
                                size: geo.size,
                                selectedID: selectedRect?.nodeID,
                                onSelect: { selectedRect = $0 },
                                onOpen: { rect in
                                    if rect.isDirectory {
                                        let node = DiskNode(
                                            id: rect.nodeID,
                                            name: rect.name,
                                            path: rect.path,
                                            isDirectory: true,
                                            byteCount: rect.byteCount
                                        )
                                        model.drill(into: node)
                                        selectedRect = nil
                                    }
                                }
                            )
                            .overlay(alignment: .bottom) {
                                if model.isLoading {
                                    Text(model.statusText)
                                        .font(.caption)
                                        .padding(8)
                                        .background(.ultraThinMaterial, in: Capsule())
                                        .padding()
                                }
                            }
                        }
                    } else {
                        EmptyStateView(
                            systemImage: "square.grid.3x3",
                            title: "Map your disk",
                            message: "See what’s using space as a squarified treemap. Drill into folders, reveal in Finder, or move to Trash.",
                            actionTitle: "Analyze Home"
                        ) {
                            model.scan(path: NSHomeDirectory())
                        }
                    }
                }
            }

            if let selectedRect {
                Divider()
                selectionBar(selectedRect)
            }
        }
        .navigationTitle("Analyze")
        .onAppear {
            if model.root == nil {
                model.scan()
            }
        }
        .confirmationDialog(
            "Move to Trash?",
            isPresented: Binding(
                get: { confirmTrashPath != nil },
                set: { if !$0 { confirmTrashPath = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                if let path = confirmTrashPath {
                    Task { _ = await model.trash(path) }
                }
                confirmTrashPath = nil
            }
            Button("Cancel", role: .cancel) {
                confirmTrashPath = nil
            }
        } message: {
            Text(confirmTrashPath ?? "")
        }
    }

    private var toolbar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Disk map")
                    .font(.title2.weight(.semibold))
                Text(model.statusText.isEmpty ? "Squarified treemap of folder sizes" : model.statusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()

            if model.isLoading {
                Button("Cancel") { model.cancel() }
            }

            Menu("Root") {
                Button("Home") { model.scan(path: NSHomeDirectory()) }
                Button("Applications") { model.scan(path: "/Applications") }
                Button("User Library") {
                    model.scan(path: (NSHomeDirectory() as NSString).appendingPathComponent("Library"))
                }
            }

            Button {
                model.scan()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isLoading)
        }
        .padding(16)
    }

    private var breadcrumbsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(model.breadcrumbs.enumerated()), id: \.offset) { index, node in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Button(node.name) {
                        model.goToBreadcrumb(index: index)
                        selectedRect = nil
                    }
                    .buttonStyle(.plain)
                    .font(index == model.breadcrumbs.count - 1 ? .callout.weight(.semibold) : .callout)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func selectionBar(_ rect: TreemapRect) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(rect.name)
                    .font(.headline)
                Text(rect.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            SizeText(bytes: rect.byteCount)
            Button("Reveal") {
                model.reveal(rect.path)
            }
            if rect.isDirectory {
                Button("Open") {
                    model.drill(
                        into: DiskNode(
                            id: rect.nodeID,
                            name: rect.name,
                            path: rect.path,
                            isDirectory: true,
                            byteCount: rect.byteCount
                        )
                    )
                    selectedRect = nil
                }
            }
            Button("Trash", role: .destructive) {
                confirmTrashPath = rect.path
            }
            .disabled(PathSafety.isProtected(rect.path))
        }
        .padding(12)
        .background(.bar)
    }
}

