//
//  ScanScreen.swift
//  Safesight
//

import SwiftUI
import PhotosUI
import UIKit

// MARK: - Scan

struct ScanScreen: View {
    @ObservedObject private var subs = SubscriptionStore.shared
    @ObservedObject private var history = ScanHistoryStore.shared
    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var chrome = ScanChromeState.shared
    @ObservedObject private var nav = AppNavigation.shared
    @StateObject private var camera = CameraController()
    @State private var showPaywall = false
    @State private var thinkingImage: UIImage?
    @State private var showThinking = false
    @State private var showGallery = false
    @State private var scanResult: ScanResult?
    @State private var resultImage: UIImage?
    @State private var highlightedHazardID: UUID?
    @State private var resultsDetent: PresentationDetent = .medium
    @State private var isCapturing = false
    @State private var retryImage: UIImage?
    @State private var showScanFailed = false
    @State private var isRetrying = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var captureMode: CaptureMode = .photo
    @State private var activeRoomIndex = 0

    private let resultsPeekDetent = PresentationDetent.height(156)

    private enum CaptureMode {
        case photo
        case video
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let resultImage, let live = liveScanResult {
                ScanAnnotatedImageView(
                    image: resultImage,
                    hazards: displayedHazards(for: live),
                    highlightedID: highlightedHazardID,
                    onSelectHazard: { id in
                        highlightedHazardID = id
                    }
                )
                .ignoresSafeArea()
            } else if let retryImage, showScanFailed || isRetrying {
                Image(uiImage: retryImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.28).ignoresSafeArea())
            } else if camera.isAuthorized {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
            } else if camera.authorizationDenied {
                permissionDenied
            } else {
                ProgressView()
                    .tint(.white)
            }

            // Top chrome (hidden while reviewing / analyzing / failure)
            if scanResult == nil && !showThinking && !showScanFailed && !isRetrying {
                VStack {
                    HStack {
                        Image("AppLogo")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 34, height: 34)
                            .foregroundStyle(.white)
                            .blendMode(.difference)
                            .accessibilityLabel("Safesight")

                        Spacer()
                        Text(
                            subs.isPremium
                                ? "Unlimited"
                                : "\(subs.remainingFreeScans) left"
                        )
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.white.opacity(0.18)))
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)

                    if camera.isRecordingVideo {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                            Text("Recording")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.black.opacity(0.45)))
                        .padding(.top, 10)
                    }

                    Spacer()

                    HStack(alignment: .center) {
                        PhotosPicker(selection: $photoPickerItem, matching: .images) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 52, height: 52)
                                .background(Circle().fill(.white.opacity(0.18)))
                        }
                        .buttonStyle(.plain)
                        .disabled(isCapturing || showThinking || isRetrying)
                        .accessibilityLabel("Upload photo")

                        Spacer()

                        captureControlCluster

                        Spacer()

                        Button {
                            Haptics.light()
                            showGallery = true
                        } label: {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 52, height: 52)
                                .background(Circle().fill(.white.opacity(0.18)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Past scans")
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 36)
                }
            }

            if showThinking, let thinkingImage {
                ScanThinkingOverlay(image: thinkingImage)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .sheet(item: $scanResult, onDismiss: {
            // Swipe-dismiss fallback: jump back if we still owe a return tab.
            finishDismissingResults()
        }) { result in
            ScanResultsDrawer(
                scanID: result.id,
                highlightedHazardID: $highlightedHazardID,
                activeRoomIndex: $activeRoomIndex,
                onDone: {
                    // Switch to Hazards *before* the sheet closes so Scan never flashes.
                    if let tab = nav.returnTabAfterScan {
                        nav.returnTabAfterScan = nil
                        nav.selectedTab = tab
                        var jump = Transaction()
                        jump.disablesAnimations = true
                        withTransaction(jump) {
                            scanResult = nil
                            highlightedHazardID = nil
                            resultImage = nil
                            resultsDetent = .medium
                        }
                    } else {
                        scanResult = nil
                    }
                },
                onScanUpdated: { updated in
                    scanResult = updated
                }
            )
            .presentationDetents(
                [resultsPeekDetent, .medium, .large],
                selection: $resultsDetent
            )
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .presentationContentInteraction(.resizes)
            .interactiveDismissDisabled(false)
        }
        .sheet(isPresented: $showScanFailed, onDismiss: {
            guard !isRetrying, !showThinking else { return }
            dismissFailedScan()
        }) {
            ScanFailedDrawer(
                isRetrying: isRetrying,
                onRetry: {
                    Task { await retryFailedScan() }
                },
                onDismiss: {
                    dismissFailedScan()
                }
            )
            .presentationDetents([.height(420), .medium])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .interactiveDismissDisabled(isRetrying)
        }
        .sheet(isPresented: $showGallery) {
            ScanGalleryView(store: history) { scan in
                nav.returnTabAfterScan = nil
                openScan(scan)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(isModal: true)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .task {
            await camera.requestAccessAndConfigure()
            camera.start()
        }
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task { await analyzeUploadedPhoto(item) }
        }
        .onChange(of: showThinking) { _, active in
            chrome.hidesTabBar = active || showScanFailed
        }
        .onChange(of: showScanFailed) { _, failed in
            chrome.hidesTabBar = failed || showThinking
        }
        .onChange(of: nav.pendingScanID) { _, id in
            guard let id else { return }
            if let scan = history.scans.first(where: { $0.id == id }) {
                openScan(scan, highlightHazardID: nav.pendingHazardID)
            }
            nav.pendingScanID = nil
            nav.pendingHazardID = nil
        }
        .onAppear {
            if let id = nav.pendingScanID,
               let scan = history.scans.first(where: { $0.id == id }) {
                openScan(scan, highlightHazardID: nav.pendingHazardID)
                nav.pendingScanID = nil
                nav.pendingHazardID = nil
            }
        }
        .onChange(of: activeRoomIndex) { _, _ in
            syncRoomPreviewImage()
        }
        .onDisappear {
            camera.stop()
            chrome.hidesTabBar = false
        }
    }

    private func displayedHazards(for result: ScanResult) -> [ScanHazardDTO] {
        if result.isVideoScan, let room = result.room(at: activeRoomIndex) {
            return room.hazards
        }
        return result.hazards
    }

    private func syncRoomPreviewImage() {
        guard let scan = liveScanResult, scan.isVideoScan else { return }
        resultImage = history.image(for: scan, roomIndex: activeRoomIndex)
        highlightedHazardID = nil
    }

    private var captureControlCluster: some View {
        VStack(spacing: 6) {
            HStack(spacing: 14) {
                captureModeButton(.photo, systemImage: "camera.fill", label: "Photo")
                captureModeButton(.video, systemImage: "video.fill", label: "Video")
            }

            Button {
                Haptics.medium()
                if captureMode == .video {
                    Task { await handleVideoCaptureTap() }
                } else {
                    Task { await takePhoto() }
                }
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: 78, height: 78)
                    Circle()
                        .fill(captureMode == .video ? Color.red : Color.white)
                        .frame(width: 64, height: 64)
                        .opacity(isCapturing ? 0.55 : 1)
                }
            }
            .buttonStyle(.plain)
            .disabled(showThinking || !camera.isAuthorized || (captureMode == .photo && isCapturing))
            .accessibilityLabel(captureMode == .video ? "Record video" : "Take photo")
        }
    }

    private func captureModeButton(
        _ mode: CaptureMode,
        systemImage: String,
        label: String
    ) -> some View {
        let selected = captureMode == mode
        return Button {
            guard captureMode != mode else { return }
            Haptics.select()
            captureMode = mode
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(selected ? .white : .white.opacity(0.4))
                .frame(width: 32, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(isCapturing || showThinking || isRetrying)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var liveScanResult: ScanResult? {
        guard let id = scanResult?.id else { return nil }
        return history.scans.first(where: { $0.id == id }) ?? scanResult
    }

    private var permissionDenied: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.8))
            Text("Camera access needed")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text("Enable camera in Settings so Safesight can scan rooms.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    private func openScan(_ scan: ScanResult, highlightHazardID: UUID? = nil) {
        activeRoomIndex = 0
        resultImage = history.image(for: scan, roomIndex: 0)
        highlightedHazardID = highlightHazardID
        resultsDetent = .medium
        showScanFailed = false
        retryImage = nil
        scanResult = scan
    }

    private func finishDismissingResults() {
        highlightedHazardID = nil
        resultImage = nil
        activeRoomIndex = 0
        resultsDetent = .medium
        if let tab = nav.returnTabAfterScan {
            nav.returnTabAfterScan = nil
            nav.selectedTab = tab
        }
    }

    private func dismissFailedScan() {
        showScanFailed = false
        retryImage = nil
        thinkingImage = nil
        chrome.hidesTabBar = false
    }

    private func handleVideoCaptureTap() async {
        guard !isCapturing else { return }
        if camera.isRecordingVideo {
            await finishVideoRecording()
        } else {
            guard subs.canScan else {
                showPaywall = true
                return
            }
            camera.startVideoRecording()
        }
    }

    private func finishVideoRecording() async {
        isCapturing = true
        let videoURL = await camera.stopVideoRecording()
        isCapturing = false
        guard let videoURL else { return }
        await processVideo(at: videoURL)
        try? FileManager.default.removeItem(at: videoURL)
    }

    private func processVideo(at url: URL) async {
        nav.returnTabAfterScan = nil
        let thumbs = VideoScanPipeline.sampleThumbnails(from: url)
        thinkingImage = thumbs[safe: thumbs.count / 2] ?? thumbs.first
        chrome.hidesTabBar = true
        var present = Transaction()
        present.disablesAnimations = true
        withTransaction(present) {
            showThinking = true
            showScanFailed = false
        }

        let route = await VideoRouterService().route(thumbnails: thumbs, maxRooms: 4)
        let segments = route.segments.isEmpty
            ? VideoScanPipeline.fallbackSegments(frameCount: thumbs.count)
            : route.segments

        var built: [(label: String, image: UIImage, hazards: [ScanHazardDTO])] = []
        for segment in segments {
            let label = VideoScanPipeline.displayLabel(for: segment.roomLabel)
            guard let image = VideoScanPipeline.fullFrame(from: url, at: segment.bestFrameIndex) else {
                continue
            }
            built.append((
                label: label,
                image: image,
                hazards: VideoScanPipeline.placeholderHazards(roomLabel: label)
            ))
        }

        if built.isEmpty, let fallback = VideoScanPipeline.fullFrame(from: url, at: 0) {
            built.append((
                label: "Room",
                image: fallback,
                hazards: VideoScanPipeline.placeholderHazards(roomLabel: "Room")
            ))
        }

        subs.recordScan()
        let scanId = UUID()
        let saved = history.saveVideoScan(scanId: scanId, rooms: built)
        history.syncInsights()

        activeRoomIndex = 0
        resultImage = history.image(for: saved, roomIndex: 0)

        var dismiss = Transaction()
        dismiss.disablesAnimations = true
        withTransaction(dismiss) {
            showThinking = false
        }
        thinkingImage = nil
        retryImage = nil
        showScanFailed = false
        resultsDetent = .medium
        try? await Task.sleep(nanoseconds: 200_000_000)
        scanResult = saved
    }

    private func takePhoto() async {
        guard !isCapturing else { return }
        if !subs.canScan {
            showPaywall = true
            return
        }

        isCapturing = true
        let captured = await camera.capturePhoto()
        isCapturing = false

        guard let captured else { return }
        let image = captured.normalizedUp()
        await runAnalysis(on: image)
    }

    private func analyzeUploadedPhoto(_ item: PhotosPickerItem) async {
        defer { photoPickerItem = nil }
        guard !showThinking, !isCapturing, !isRetrying else { return }
        if !subs.canScan {
            showPaywall = true
            return
        }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let raw = UIImage(data: data) else {
            return
        }
        Haptics.medium()
        await runAnalysis(on: raw.normalizedUp())
    }

    private func retryFailedScan() async {
        guard let image = retryImage, !isRetrying else { return }
        isRetrying = true
        defer { isRetrying = false }
        // Close the failed drawer first; thinking overlay takes over in runAnalysis.
        showScanFailed = false
        await runAnalysis(on: image)
    }

    /// Charges a free scan only after a successful analysis.
    private func runAnalysis(on image: UIImage) async {
        nav.returnTabAfterScan = nil
        thinkingImage = image
        chrome.hidesTabBar = true
        var present = Transaction()
        present.disablesAnimations = true
        withTransaction(present) {
            showThinking = true
            showScanFailed = false
        }

        let scanId = UUID()
        let request = ScanAnalysisRequest(
            scanId: scanId,
            focusAreas: profiles.profile?.hazards.map(\.rawValue) ?? [],
            dwelling: profiles.profile?.dwelling.rawValue,
            imageBase64: nil,
            aggressiveness: profiles.scanAggressiveness,
            maxHazards: profiles.maxHazardsPerScan
        )

        let analyzer = ScanAnalyzerFactory.make()
        let response: ScanAnalysisResponse
        do {
            var analyzed = try await analyzer.analyze(request: request, image: image)
            if !analyzed.hazards.isEmpty {
                analyzed.products = await AmazonProductService.shared.products(
                    for: analyzed.hazards,
                    suggested: analyzed.products
                )
            } else {
                analyzed.products = []
            }
            response = analyzed
        } catch {
            #if DEBUG
            print("Scan analysis failed: \(error)")
            #endif
            var dismiss = Transaction()
            dismiss.disablesAnimations = true
            withTransaction(dismiss) {
                showThinking = false
            }
            thinkingImage = nil
            retryImage = image
            showScanFailed = true
            chrome.hidesTabBar = true
            return
        }

        // Success — now count the scan.
        subs.recordScan()

        let saved = history.save(image: image, response: response, scanId: scanId)
        history.syncInsights()

        var dismiss = Transaction()
        dismiss.disablesAnimations = true
        withTransaction(dismiss) {
            showThinking = false
        }
        thinkingImage = nil
        retryImage = nil
        showScanFailed = false

        resultImage = image
        resultsDetent = .medium
        try? await Task.sleep(nanoseconds: 200_000_000)
        scanResult = saved
        activeRoomIndex = 0
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
