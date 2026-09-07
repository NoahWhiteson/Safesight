//
//  AppleIntelligenceGlow.swift
//  Safesight
//
//  Production Apple Intelligence ambient edge-glow.
//  Visual physics: conic (angular) color transport + three-tier diffusion +
//  liquid motion so energy reads as living plasma, not a spinning wheel.
//

import Combine
import SwiftUI
import UIKit

// MARK: - Public API

extension View {
    /// Ambient Apple Intelligence edge glow flush to the view bounds.
    func appleIntelligenceGlow(
        isActive: Bool = true,
        cornerRadius: CGFloat? = nil,
        intensity: Double = 1.0
    ) -> some View {
        modifier(
            AppleIntelligenceGlowModifier(
                isActive: isActive,
                cornerRadius: cornerRadius,
                intensity: intensity
            )
        )
    }
}

/// Drop-in full-screen thinking chrome (photo + edge glow + status capsule).
struct AppleIntelligenceThinkingChrome: View {
    let image: UIImage
    var title: String = "Analyzing room…"
    var subtitle: String = "Matching your focus areas"

    @State private var contentOpacity = 0.0
    @State private var glowOpacity = 0.0

    var body: some View {
        GeometryReader { geo in
            let radius = DisplayCornerRadius.resolve(for: geo.size)

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .overlay { Color.black.opacity(0.16) }

                Color.clear
                    .appleIntelligenceGlow(
                        isActive: true,
                        cornerRadius: radius,
                        intensity: 1.0
                    )
                    .opacity(glowOpacity)
                    .allowsHitTesting(false)

                ThinkingStatusCapsule(title: title, subtitle: subtitle)
                    .opacity(contentOpacity)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) {
                contentOpacity = 1
            }
            // Glow eases in a beat later so the rim “ignites.”
            withAnimation(.easeInOut(duration: 0.85).delay(0.08)) {
                glowOpacity = 1
            }
        }
    }
}

// MARK: - Display corner radius

private enum DisplayCornerRadius {
    /// Prefer the real device display radius so top/bottom bezels match.
    static func resolve(for size: CGSize) -> CGFloat {
        if let screen = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?
            .screen {
            for key in ["displayCornerRadius", "_displayCornerRadius"] {
                if let radius = screen.value(forKey: key) as? CGFloat, radius > 0 {
                    return radius
                }
            }
        }

        let shortest = min(size.width, size.height)
        if shortest >= 430 { return 55 }
        if shortest >= 390 { return 53 }
        if shortest >= 360 { return 47 }
        return 39
    }
}

// MARK: - ViewModifier

private struct AppleIntelligenceGlowModifier: ViewModifier {
    let isActive: Bool
    let cornerRadius: CGFloat?
    let intensity: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    func body(content: Content) -> some View {
        content.overlay {
            if isActive {
                GeometryReader { geo in
                    AppleIntelligenceGlowCanvas(
                        cornerRadius: cornerRadius ?? DisplayCornerRadius.resolve(for: geo.size),
                        intensity: intensity,
                        reduceMotion: reduceMotion,
                        lowPower: lowPower
                    )
                }
                .allowsHitTesting(false)
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .NSProcessInfoPowerStateDidChange
            )
        ) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
}

// MARK: - Glow engine

private struct AppleIntelligenceGlowCanvas: View {
    let cornerRadius: CGFloat
    let intensity: Double
    let reduceMotion: Bool
    let lowPower: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: frameInterval, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = reduceMotion ? 0 : t
            let waveA = fract(phase * 0.18)
            let waveB = fract(phase * 0.18 + 0.52)

            GeometryReader { geo in
                // Full bounds — stroke sits on the true edge (half line inside).
                let rect = CGRect(origin: .zero, size: geo.size)

                ZStack {
                    // Deep outer bloom — projects past the bezel
                    if !lowPower {
                        edgeStroke(
                            in: rect,
                            phase: phase,
                            lineWidth: 28,
                            blur: 36,
                            opacity: 0.38 * intensity,
                            rotateSpeed: 9,
                            amplitude: 6.5,
                            waveFreq: 2.2
                        )
                        edgeStroke(
                            in: rect,
                            phase: phase,
                            lineWidth: 18,
                            blur: 22,
                            opacity: 0.48 * intensity,
                            rotateSpeed: 11,
                            amplitude: 5.5,
                            waveFreq: 2.5
                        )
                    }

                    edgeStroke(
                        in: rect,
                        phase: phase,
                        lineWidth: lowPower ? 7 : 11,
                        blur: lowPower ? 6 : 10,
                        opacity: 0.9 * intensity,
                        rotateSpeed: 16,
                        amplitude: lowPower ? 2.0 : 4.5,
                        waveFreq: 3.0
                    )

                    edgeStroke(
                        in: rect,
                        phase: phase,
                        lineWidth: 1.6,
                        blur: 0.15,
                        opacity: 1.0 * intensity,
                        rotateSpeed: 22,
                        amplitude: lowPower ? 1.6 : 3.4,
                        waveFreq: 3.4
                    )

                    if !reduceMotion {
                        runningWave(
                            in: rect,
                            head: waveA,
                            phase: phase,
                            amplitude: lowPower ? 2.4 : 4.5,
                            width: 0.18,
                            blur: lowPower ? 6 : 12,
                            opacity: 1.2 * intensity
                        )

                        if !lowPower {
                            runningWave(
                                in: rect,
                                head: waveB,
                                phase: phase * 0.95,
                                amplitude: 3.6,
                                width: 0.12,
                                blur: 10,
                                opacity: 0.85 * intensity
                            )
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                // Slight overscale so bloom reads outside the glass edge.
                .scaleEffect(1.012)
                .drawingGroup(opaque: false, colorMode: .linear)
            }
        }
        .ignoresSafeArea()
    }

    private var frameInterval: TimeInterval {
        if reduceMotion { return 1.0 / 10.0 }
        if lowPower { return 1.0 / 15.0 }
        return 1.0 / 30.0
    }

    private func edgeStroke(
        in rect: CGRect,
        phase: TimeInterval,
        lineWidth: CGFloat,
        blur: CGFloat,
        opacity: Double,
        rotateSpeed: Double,
        amplitude: CGFloat,
        waveFreq: Double
    ) -> some View {
        let stops = AppleIntelligencePalette.liquidStops(time: phase, jitter: 0.04)
        let path = WavyEdgePath.make(
            in: rect,
            cornerRadius: cornerRadius,
            time: phase,
            amplitude: amplitude,
            frequency: waveFreq
        )

        return path
            .stroke(
                AngularGradient(
                    gradient: Gradient(stops: stops),
                    center: .center,
                    angle: .degrees(phase * rotateSpeed)
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
            .blur(radius: blur)
            .opacity(opacity)
            .blendMode(.plusLighter)
    }

    private func runningWave(
        in rect: CGRect,
        head: Double,
        phase: TimeInterval,
        amplitude: CGFloat,
        width: Double,
        blur: CGFloat,
        opacity: Double
    ) -> some View {
        let path = WavyEdgePath.make(
            in: rect,
            cornerRadius: cornerRadius,
            time: phase,
            amplitude: amplitude,
            frequency: 3.2
        )

        let start = CGFloat(fract(head))
        let end = start + CGFloat(width)
        let style = StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
        let paint = AngularGradient(
            colors: [
                Color(aiHex: 0x5AC8FA),
                .white,
                Color(aiHex: 0xFF9F0A),
                Color(aiHex: 0xBF5AF2),
                Color(aiHex: 0xFF375F)
            ],
            center: .center,
            angle: .degrees(phase * 40)
        )

        return ZStack {
            path.trimmedPath(from: start, to: min(1, end))
                .stroke(paint, style: style)
            if end > 1 {
                path.trimmedPath(from: 0, to: end - 1)
                    .stroke(paint, style: style)
            }
        }
        .blur(radius: blur)
        .opacity(opacity)
        .blendMode(.plusLighter)
        .shadow(color: Color(aiHex: 0xBF5AF2).opacity(0.55), radius: 10)
    }

    private func fract(_ x: Double) -> Double {
        x - floor(x)
    }
}

// MARK: - Wavy edge path

/// Continuous (squircle) perimeter + edge-only wave. Amplitude tapers to 0 in
/// the corners so top/bottom radii stay locked to the display bezel.
private enum WavyEdgePath {
    static func make(
        in rect: CGRect,
        cornerRadius: CGFloat,
        time: TimeInterval,
        amplitude: CGFloat,
        frequency: Double,
        samples: Int = 240
    ) -> Path {
        // Hairline inset so the stroke centers on the physical edge.
        let inset: CGFloat = 0.75
        let r = rect.insetBy(dx: inset, dy: inset)
        let radius = min(cornerRadius, min(r.width, r.height) * 0.5)

        // Device-matching continuous corners (not circular arcs).
        let base = Path(roundedRect: r, cornerRadius: radius, style: .continuous)
        let points = sample(path: base, count: samples)
        guard points.count > 2 else { return base }

        // Corner zones along normalized perimeter — kill wave there.
        let cornerSpan = Double(radius / max(r.width + r.height, 1)) * 1.35

        var out = Path()
        for i in 0..<points.count {
            let curr = points[i]
            let prev = points[(i - 1 + points.count) % points.count]
            let next = points[(i + 1) % points.count]

            let tx = next.x - prev.x
            let ty = next.y - prev.y
            let len = max(0.0001, hypot(tx, ty))
            let nx = ty / len
            let ny = -tx / len

            let u = Double(i) / Double(points.count)
            let edgeWeight = edgeWaveWeight(u: u, cornerSpan: cornerSpan)

            let s = u * .pi * 2
            let wave =
                sin(s * frequency + time * 3.6) * 0.55
                + sin(s * (frequency * 1.85) - time * 2.4) * 0.30
                + sin(s * 0.65 + time * 1.5) * 0.15

            // Pure edge undulation — no constant outward bias (that skewed corners).
            let displacement = amplitude * CGFloat(wave) * CGFloat(edgeWeight)
            let p = CGPoint(x: curr.x + nx * displacement, y: curr.y + ny * displacement)

            if i == 0 {
                out.move(to: p)
            } else {
                out.addLine(to: p)
            }
        }
        out.closeSubpath()
        return out
    }

    /// 0 at corners, 1 along straight edges — smooth cosine taper.
    private static func edgeWaveWeight(u: Double, cornerSpan: Double) -> Double {
        // Continuous-rect perimeter parameterization starts mid-ish depending on
        // path winding; treat four corner bands near 0/0.25/0.5/0.75.
        let corners: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]
        var nearest = 1.0
        for c in corners {
            let d = abs(u - c)
            nearest = min(nearest, min(d, 1.0 - d))
        }
        let t = min(1.0, nearest / max(cornerSpan, 0.02))
        // Smoothstep
        return t * t * (3 - 2 * t)
    }

    private static func sample(path: Path, count: Int) -> [CGPoint] {
        var points: [CGPoint] = []
        points.reserveCapacity(count)
        for i in 0..<count {
            let u = CGFloat(i) / CGFloat(count)
            let slice = path.trimmedPath(from: u, to: min(1, u + 0.0015))
            let box = slice.boundingRect
            points.append(CGPoint(x: box.midX, y: box.midY))
        }
        return points
    }
}

// MARK: - Palette & liquid stop mathematics

private enum AppleIntelligencePalette {
    static let sequence: [Color] = [
        Color(aiHex: 0x5AC8FA),
        Color(aiHex: 0x7B61FF),
        Color(aiHex: 0xBF5AF2),
        Color(aiHex: 0xFF375F),
        Color(aiHex: 0xFF9F0A),
        Color(aiHex: 0x5AC8FA)
    ]

    static func liquidStops(time: TimeInterval, jitter: Double) -> [Gradient.Stop] {
        let count = sequence.count
        return sequence.enumerated().map { index, color in
            let base = Double(index) / Double(count - 1)
            let wave =
                sin(time * (0.9 + Double(index) * 0.15) + Double(index) * 1.1) * jitter
                + cos(time * (0.55 + Double(index) * 0.1) + Double(index) * 0.7) * (jitter * 0.55)
            let location = min(1, max(0, base + wave))
            return Gradient.Stop(color: color, location: location)
        }
        .sorted { $0.location < $1.location }
    }
}

private extension Color {
    init(aiHex: UInt32) {
        self.init(
            red: Double((aiHex >> 16) & 0xFF) / 255,
            green: Double((aiHex >> 8) & 0xFF) / 255,
            blue: Double(aiHex & 0xFF) / 255
        )
    }
}

// MARK: - Status capsule

private struct ThinkingStatusCapsule: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(
                    .linearGradient(
                        colors: AppleIntelligencePalette.sequence,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.variableColor.iterative, options: .repeating)

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .strokeBorder(
                            AngularGradient(
                                colors: AppleIntelligencePalette.sequence,
                                center: .center
                            ),
                            lineWidth: 1.1
                        )
                        .opacity(0.65)
                }
        }
    }
}

#if DEBUG
struct AppleIntelligenceGlowExample: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, Color(white: 0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Text("Your content")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
        }
        .appleIntelligenceGlow(isActive: true)
    }
}

#Preview("Glow modifier") {
    AppleIntelligenceGlowExample()
}
#endif
