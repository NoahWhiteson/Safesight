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

    private let resultsPeekDetent = PresentationDetent.height(156)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let resultImage, let live = liveScanResult {
                ScanAnnotatedImageView(
                    image: resultImage,
                    hazards: live.hazards,
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

                        Button {
                            Haptics.medium()
                            Task { await takePhoto() }
                        } label: {
                            ZStack {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 4)
                                    .frame(width: 78, height: 78)
                                Circle()
                                    .fill(.white)
                                    .frame(width: 64, height: 64)
                                    .opacity(isCapturing ? 0.55 : 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isCapturing || showThinking || !camera.isAuthorized)

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
            highlightedHazardID = nil
            resultImage = nil
            resultsDetent = .medium
            if let tab = nav.returnTabAfterScan {
                nav.returnTabAfterScan = nil
                nav.selectedTab = tab
            }
        }) { result in
            ScanResultsDrawer(
                scanID: result.id,
                highlightedHazardID: $highlightedHazardID,
                onDone: { scanResult = nil },
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
        .onDisappear {
            camera.stop()
            chrome.hidesTabBar = false
        }
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
        resultImage = history.image(for: scan)
        highlightedHazardID = highlightHazardID
        resultsDetent = .medium
        showScanFailed = false
        retryImage = nil
        scanResult = scan
    }

    private func dismissFailedScan() {
        showScanFailed = false
        retryImage = nil
        thinkingImage = nil
        chrome.hidesTabBar = false
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
    }
}
