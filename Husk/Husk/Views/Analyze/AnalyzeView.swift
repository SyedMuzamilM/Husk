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
            if model.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.bottom, 6)
            }
            Divider()
            breadcrumbsBar
            Divider()

            GeometryReader { geo in
                ZStack {
                    if model.isLoading && model.current == nil {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text(model.statusText)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Cancel") { model.cancel() }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let current = model.current {
                        let children = current.sortedChildren()
                        if children.isEmpty {
                            EmptyStateView(
                                systemImage: "folder",
                                title: "Empty or unreadable",
                                message: current.path,
                                actionTitle: "Go Up"
                            ) {
                                if !model.pathStack.isEmpty {
                                    model.goToBreadcrumb(index: max(0, model.breadcrumbs.count - 2))
                                }
                            }
                        } else {
                            TreemapView(
                                nodes: children,
                                size: geo.size,
                                selectedID: selectedRect?.nodeID,
                                onSelect: { selectedRect = $0 },
                                onOpen: { rect in
                                    if rect.isDirectory {
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
                            )
                        }
                    } else {
                        EmptyStateView(
                            systemImage: "square.grid.3x3",
                            title: "Map your disk",
                            message: "See what's using space as a squarified treemap. Start with Library or Downloads for a faster map — Home can take longer.",
                            actionTitle: "Analyze Library"
                        ) {
                            model.scan(
                                path: (NSHomeDirectory() as NSString).appendingPathComponent("Library")
                            )
                        }
                    }
                }
            }

            if let error = model.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }

            if let selectedRect {
                Divider()
                selectionBar(selectedRect)
            }
        }
        .navigationTitle("Analyze")
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
                selectedRect = nil
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
                Text(model.statusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()

            if model.isLoading {
                Button("Cancel") { model.cancel() }
            }

            Menu("Location") {
                Button("Home") { model.scan(path: NSHomeDirectory()) }
                Button("Library") {
                    model.scan(path: (NSHomeDirectory() as NSString).appendingPathComponent("Library"))
                }
                Button("Downloads") {
                    model.scan(path: (NSHomeDirectory() as NSString).appendingPathComponent("Downloads"))
                }
                Button("Documents") {
                    model.scan(path: (NSHomeDirectory() as NSString).appendingPathComponent("Documents"))
                }
                Button("Applications") { model.scan(path: "/Applications") }
                Button("User Caches") {
                    model.scan(
                        path: (NSHomeDirectory() as NSString).appendingPathComponent("Library/Caches")
                    )
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
                if model.breadcrumbs.isEmpty {
                    Text("No map yet")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(model.breadcrumbs.enumerated()), id: \.offset) { index, node in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Button(node.name.isEmpty ? "/" : node.name) {
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
            Button("Reveal") { model.reveal(rect.path) }
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
                .disabled(model.isLoading)
            }
            Button("Trash", role: .destructive) {
                confirmTrashPath = rect.path
            }
            .disabled(PathSafety.isProtected(rect.path) || model.isLoading)
        }
        .padding(12)
        .background(.bar)
    }
}
