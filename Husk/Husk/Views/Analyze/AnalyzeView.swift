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
            header
            if model.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(Color.huskPrimary)
                    .padding(.bottom, 8)
            }
            breadcrumbs
            treemapArea
            if let selectedRect {
                selectionBar(selectedRect)
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
                selectedRect = nil
            }
            Button("Cancel", role: .cancel) { confirmTrashPath = nil }
        } message: {
            Text(confirmTrashPath ?? "")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Storage Analysis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.huskText)
                Text(model.statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.huskTextMuted)
                    .lineLimit(1)
            }
            Spacer()
            if model.isLoading {
                Button("Cancel") { model.cancel() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.huskTextSecondary)
            }
            Menu {
                Button("Library") {
                    model.scan(path: (NSHomeDirectory() as NSString).appendingPathComponent("Library"))
                }
                Button("Downloads") {
                    model.scan(path: (NSHomeDirectory() as NSString).appendingPathComponent("Downloads"))
                }
                Button("Documents") {
                    model.scan(path: (NSHomeDirectory() as NSString).appendingPathComponent("Documents"))
                }
                Button("Home") { model.scan(path: NSHomeDirectory()) }
                Button("Applications") { model.scan(path: "/Applications") }
                Button("User Caches") {
                    model.scan(path: (NSHomeDirectory() as NSString).appendingPathComponent("Library/Caches"))
                }
            } label: {
                Label("Location", systemImage: "folder")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.huskSurfaceHigh))
                    .foregroundStyle(Color.huskText)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, HuskTheme.contentPadding)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private var breadcrumbs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if model.breadcrumbs.isEmpty {
                    Text("Pick a location to map folders like node_modules, Builds, Caches…")
                        .font(.caption)
                        .foregroundStyle(Color.huskTextMuted)
                }
                ForEach(Array(model.breadcrumbs.enumerated()), id: \.offset) { index, node in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(Color.huskTextMuted)
                    }
                    Button(node.name.isEmpty ? "Disk" : node.name) {
                        model.goToBreadcrumb(index: index)
                        selectedRect = nil
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: index == model.breadcrumbs.count - 1 ? .semibold : .regular))
                    .foregroundStyle(index == model.breadcrumbs.count - 1 ? Color.huskPrimary : Color.huskTextSecondary)
                }
            }
            .padding(.horizontal, HuskTheme.contentPadding)
            .padding(.bottom, 10)
        }
    }

    private var treemapArea: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: HuskTheme.cardRadius, style: .continuous)
                    .fill(Color.huskSurface.opacity(0.65))
                    .overlay(
                        RoundedRectangle(cornerRadius: HuskTheme.cardRadius, style: .continuous)
                            .strokeBorder(Color.huskBorder)
                    )

                if model.isLoading && model.current == nil {
                    VStack(spacing: 12) {
                        ProgressView().tint(Color.huskPrimary)
                        Text(model.statusText)
                            .font(.caption)
                            .foregroundStyle(Color.huskTextMuted)
                    }
                } else if let current = model.current {
                    let children = current.sortedChildren()
                    if children.isEmpty {
                        Text("Empty or unreadable")
                            .foregroundStyle(Color.huskTextMuted)
                    } else {
                        TreemapView(
                            nodes: children,
                            size: CGSize(width: geo.size.width - 16, height: geo.size.height - 16),
                            selectedID: selectedRect?.nodeID,
                            onSelect: { selectedRect = $0 },
                            onOpen: { rect in
                                if rect.isDirectory {
                                    model.drill(into: DiskNode(
                                        id: rect.nodeID,
                                        name: rect.name,
                                        path: rect.path,
                                        isDirectory: true,
                                        byteCount: rect.byteCount
                                    ))
                                    selectedRect = nil
                                }
                            }
                        )
                        .padding(8)
                    }
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(Color.huskTeal.opacity(0.8))
                        Text("Map project bulk")
                            .font(.headline)
                            .foregroundStyle(Color.huskText)
                        Text("See node_modules, build folders, and caches as a treemap.")
                            .font(.caption)
                            .foregroundStyle(Color.huskTextMuted)
                        HuskPillButton(title: "Analyze Library", systemImage: "square.grid.2x2") {
                            model.scan(path: (NSHomeDirectory() as NSString).appendingPathComponent("Library"))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, HuskTheme.contentPadding)
        .padding(.bottom, 12)
    }

    private func selectionBar(_ rect: TreemapRect) -> some View {
        HStack(spacing: 12) {
            Image(systemName: rect.isDirectory ? "folder.fill" : "doc")
                .foregroundStyle(Color.huskPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text(rect.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.huskText)
                Text(rect.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.huskTextMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(ByteFormat.string(for: rect.byteCount))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.huskPrimary)
            Button("Reveal") { model.reveal(rect.path) }
                .buttonStyle(.plain)
                .foregroundStyle(Color.huskTextSecondary)
            if rect.isDirectory {
                Button("Open") {
                    model.drill(into: DiskNode(
                        id: rect.nodeID, name: rect.name, path: rect.path,
                        isDirectory: true, byteCount: rect.byteCount
                    ))
                    selectedRect = nil
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.huskTextSecondary)
            }
            HuskPillButton(title: "Move to Trash", systemImage: "trash", prominent: true) {
                confirmTrashPath = rect.path
            }
            .disabled(PathSafety.isProtected(rect.path))
            .scaleEffect(0.92)
        }
        .padding(.horizontal, HuskTheme.contentPadding)
        .padding(.vertical, 12)
        .background(Color.huskSurfaceLow.opacity(0.95))
        .overlay(alignment: .top) { Rectangle().fill(Color.huskBorder).frame(height: 1) }
    }
}
