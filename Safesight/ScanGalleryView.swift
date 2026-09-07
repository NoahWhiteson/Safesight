//
//  ScanGalleryView.swift
//  Safesight
//

import SwiftUI
import UIKit

struct ScanGalleryView: View {
    @ObservedObject var store: ScanHistoryStore
    var onSelect: (ScanResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []

    private let ink = Color(white: 0.08)
    private let mute = Color(white: 0.45)
    private let bg = Color(red: 0.96, green: 0.96, blue: 0.97)
    private let blue = Color(red: 0.0, green: 0.48, blue: 1.0)

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var selectedScans: [ScanResult] {
        store.scans.filter { selectedIDs.contains($0.id) }
    }

    private var allSelectedStarred: Bool {
        !selectedScans.isEmpty && selectedScans.allSatisfy(\.isStarred)
    }

    private var selectedTitle: String {
        selectedIDs.isEmpty ? "Select Scans" : "\(selectedIDs.count) Selected"
    }

    var body: some View {
        NavigationStack {
            content
                .background(bg.ignoresSafeArea())
                .navigationTitle(isSelecting ? selectedTitle : "Past scans")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .safeAreaInset(edge: .bottom) {
                    if isSelecting { selectionBar }
                }
                .onAppear { store.purgeExpired() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.scans.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(store.scans) { scan in
                        ScanGalleryCell(
                            scan: scan,
                            image: store.image(for: scan),
                            isSelecting: isSelecting,
                            isSelected: selectedIDs.contains(scan.id),
                            hasSelection: !selectedIDs.isEmpty,
                            ink: ink,
                            mute: mute,
                            blue: blue
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .onTapGesture { handleTap(scan) }
                        .onLongPressGesture(minimumDuration: 0.35) { handleLongPress(scan) }
                        .contextMenu { contextMenu(for: scan) }
                    }
                }
                .padding(20)
                .padding(.bottom, isSelecting ? 72 : 0)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(mute)
            Text("No scans yet")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(ink)
            Text("Take a photo on Scan and past results will land here.")
                .font(.system(size: 15))
                .foregroundStyle(mute)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if isSelecting {
                Button("Cancel") {
                    Haptics.light()
                    exitSelection()
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if isSelecting {
                Button(selectedIDs.count == store.scans.count ? "Deselect All" : "Select All") {
                    Haptics.light()
                    if selectedIDs.count == store.scans.count {
                        selectedIDs.removeAll()
                    } else {
                        selectedIDs = Set(store.scans.map(\.id))
                    }
                }
                .fontWeight(.semibold)
            } else {
                Button("Done") {
                    Haptics.light()
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }

    private var selectionBar: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.light()
                guard !selectedIDs.isEmpty else { return }
                store.setStarred(selectedIDs, starred: !allSelectedStarred)
            } label: {
                Label(
                    allSelectedStarred ? "Unstar" : "Star",
                    systemImage: allSelectedStarred ? "star.slash.fill" : "star.fill"
                )
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white)
                )
                .foregroundStyle(selectedIDs.isEmpty ? mute : blue)
            }
            .buttonStyle(.plain)
            .disabled(selectedIDs.isEmpty)

            Button(role: .destructive) {
                Haptics.warning()
                guard !selectedIDs.isEmpty else { return }
                let ids = selectedIDs
                store.delete(ids: ids)
                selectedIDs.removeAll()
                if store.scans.isEmpty { exitSelection() }
            } label: {
                Label("Delete", systemImage: "trash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white)
                    )
                    .foregroundStyle(
                        selectedIDs.isEmpty
                            ? mute
                            : Color(red: 0.92, green: 0.28, blue: 0.25)
                    )
            }
            .buttonStyle(.plain)
            .disabled(selectedIDs.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func contextMenu(for scan: ScanResult) -> some View {
        Button {
            Haptics.light()
            store.toggleStarred(scan)
        } label: {
            Label(
                scan.isStarred ? "Unstar" : "Star",
                systemImage: scan.isStarred ? "star.slash" : "star"
            )
        }
        Button(role: .destructive) {
            Haptics.warning()
            store.delete(scan)
            selectedIDs.remove(scan.id)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func handleTap(_ scan: ScanResult) {
        Haptics.light()
        if isSelecting {
            toggleSelection(scan.id)
        } else {
            onSelect(scan)
            dismiss()
        }
    }

    private func handleLongPress(_ scan: ScanResult) {
        Haptics.medium()
        if !isSelecting { isSelecting = true }
        selectedIDs.insert(scan.id)
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func exitSelection() {
        isSelecting = false
        selectedIDs.removeAll()
    }
}

struct ScanGalleryCell: View {
    let scan: ScanResult
    let image: UIImage?
    let isSelecting: Bool
    let isSelected: Bool
    let hasSelection: Bool
    let ink: Color
    let mute: Color
    let blue: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                thumb
                badges
            }

            Text(scan.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(mute)

            Text("\(scan.openHazardCount) open · \(scan.hazards.count) total")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ink)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .opacity(isSelecting && !isSelected && hasSelection ? 0.72 : 1)
    }

    private var thumb: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(white: 0.92)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            if isSelecting {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? blue : Color.white.opacity(0.35), lineWidth: isSelected ? 3 : 1)
            }
        }
    }

    private var badges: some View {
        HStack(spacing: 6) {
            if scan.isStarred {
                Image(systemName: "star.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.04))
                    .padding(6)
                    .background(Circle().fill(Color.black.opacity(0.55)))
            }

            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        isSelected ? Color.white : Color.white.opacity(0.9),
                        isSelected ? blue : Color.clear
                    )
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            } else {
                Text("\(scan.score)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
            }
        }
        .padding(8)
    }
}
