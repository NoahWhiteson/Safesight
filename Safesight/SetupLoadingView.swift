//
//  SetupLoadingView.swift
//  Safesight
//

import SwiftUI

struct SetupLoadingView: View {
    let onFinished: () -> Void

    @State private var appeared = false
    @State private var spin = false

    var body: some View {
        ZStack {
            Color(white: 0.96).ignoresSafeArea()

            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .stroke(Color(white: 0.88), lineWidth: 4)
                        .frame(width: 56, height: 56)

                    Circle()
                        .trim(from: 0, to: 0.28)
                        .stroke(Color(white: 0.12), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(spin ? 360 : 0))
                }

                VStack(spacing: 8) {
                    Text("Setting up your profile")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(white: 0.1))
                        .multilineTextAlignment(.center)

                    Text("Personalizing Safesight for your home.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(white: 0.45))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
            }
            .opacity(appeared ? 1 : 0)
        }
        .preferredColorScheme(.light)
        .onAppear {
            withAnimation(.default) { appeared = true }
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) { spin = true }

            let delay = Double.random(in: 2.0...5.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                onFinished()
            }
        }
    }
}
