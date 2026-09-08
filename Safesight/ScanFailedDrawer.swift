//
//  ScanFailedDrawer.swift
//  Safesight
//

import SwiftUI

struct ScanFailedDrawer: View {
    var isRetrying: Bool
    var onRetry: () -> Void
    var onDismiss: () -> Void

    private let ink = Color(white: 0.08)
    private let mute = Color(white: 0.45)
    private let bg = Color(red: 0.96, green: 0.96, blue: 0.97)
    private let warn = Color(red: 0.92, green: 0.35, blue: 0.32)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(warn.opacity(0.12))
                                .frame(width: 72, height: 72)
                            Image(systemName: "wifi.exclamationmark")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(warn)
                        }
                        .padding(.top, 8)

                        Text("Scan failed")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(ink)

                        Text("No scan credit used. Check your connection and try again — your photo is still here.")
                            .font(.system(size: 15))
                            .foregroundStyle(mute)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white)
                    )

                    VStack(spacing: 12) {
                        Button {
                            Haptics.medium()
                            onRetry()
                        } label: {
                            HStack(spacing: 8) {
                                if isRetrying {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text(isRetrying ? "Retrying…" : "Retry scan")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                Capsule().fill(ink)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isRetrying)

                        Button {
                            Haptics.light()
                            onDismiss()
                        } label: {
                            Text("Dismiss")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(mute)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule().fill(Color.white)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isRetrying)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(bg.ignoresSafeArea())
            .navigationTitle("Something went wrong")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        Haptics.light()
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(isRetrying)
                }
            }
            .interactiveDismissDisabled(isRetrying)
        }
    }
}
