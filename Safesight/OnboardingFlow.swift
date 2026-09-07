//
//  OnboardingFlow.swift
//  Safesight
//

import SwiftUI
import UIKit

// MARK: - Model

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case name
    case dwelling
    case hazards
    case complete
}

enum DwellingType: String, CaseIterable, Identifiable {
    case house = "House"
    case condo = "Condo"
    case apartment = "Apartment"
    case townhouse = "Townhouse"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .house: return "house.fill"
        case .condo: return "building.2.fill"
        case .apartment: return "building.fill"
        case .townhouse: return "building.columns.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .house: return "Detached or semi-detached home"
        case .condo: return "Owned unit in a shared building"
        case .apartment: return "Rented flat or suite"
        case .townhouse: return "Shared walls, private entrance"
        case .other: return "Something else entirely"
        }
    }
}

enum SafetyInterest: String, CaseIterable, Identifiable {
    // Free (max 6) — camera-visible
    case fire = "Fire"
    case water = "Water leaks"
    case electric = "Electric"
    case childProofing = "Child proofing"
    case trip = "Trip hazards"
    case blocked = "Blocked exits"
    // Premium — camera-visible
    case mold = "Mold & stains"
    case chemicals = "Chemical storage"
    case sharp = "Sharp objects"
    case stairs = "Stairs & falls"
    case windows = "Windows & falls"
    case pets = "Pet hazards"
    case leadPaint = "Peeling paint"
    case firearm = "Firearm storage"
    case kitchen = "Kitchen hazards"
    case nightLighting = "Poor lighting"
    case tipOver = "Tip-over risks"

    var id: String { rawValue }

    var requiresPremium: Bool {
        switch self {
        case .fire, .water, .electric, .childProofing, .trip, .blocked:
            return false
        default:
            return true
        }
    }

    var icon: String {
        switch self {
        case .fire: return "flame.fill"
        case .water: return "drop.fill"
        case .electric: return "bolt.fill"
        case .childProofing: return "figure.and.child.holdinghands"
        case .trip: return "figure.walk"
        case .blocked: return "door.left.hand.closed"
        case .mold: return "humidity.fill"
        case .chemicals: return "flask.fill"
        case .sharp: return "scissors"
        case .stairs: return "figure.stairs"
        case .windows: return "window.horizontal"
        case .pets: return "pawprint.fill"
        case .leadPaint: return "paintbrush.fill"
        case .firearm: return "lock.shield.fill"
        case .kitchen: return "fork.knife"
        case .nightLighting: return "lightbulb.fill"
        case .tipOver: return "rectangle.portrait.and.arrow.right"
        }
    }

    static var freeCases: [SafetyInterest] {
        [.fire, .water, .electric, .childProofing, .trip, .blocked]
    }

    static func available(isPremium: Bool) -> [SafetyInterest] {
        isPremium ? Array(allCases) : freeCases
    }
}

// MARK: - Flow

struct OnboardingFlow: View {
    var onFinished: (String, DwellingType, Set<SafetyInterest>) -> Void = { _, _, _ in }

    @State private var step: OnboardingStep = .welcome
    @State private var name = ""
    @State private var dwelling: DwellingType?
    @State private var hazards: Set<SafetyInterest> = []
    @FocusState private var nameFocused: Bool

    private var canAdvance: Bool {
        switch step {
        case .welcome: return true
        case .name: return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .dwelling: return dwelling != nil
        case .hazards: return !hazards.isEmpty
        case .complete: return true
        }
    }

    private func topRatio(for step: OnboardingStep) -> CGFloat {
        switch step {
        case .name: return 0.30
        case .dwelling: return 0.32
        case .hazards: return 0.24
        case .complete: return 0.06
        default: return 0.22
        }
    }

    var body: some View {
        GeometryReader { geo in
            let topHeight = geo.size.height * topRatio(for: step)
            let cardHeight = geo.size.height * (1 - topRatio(for: step))
            let footerWidth = geo.size.width - 48

            ZStack(alignment: .top) {
                Color.white.ignoresSafeArea()

                topBand(topHeight: topHeight)
                    .frame(height: topHeight + geo.safeAreaInsets.top)
                    .frame(maxWidth: .infinity)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    VStack(spacing: 0) {
                        if step != .welcome {
                            HStack {
                                Spacer()
                                Text(stepLabel)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color(white: 0.45))
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 18)
                            .padding(.bottom, 6)
                        }

                        Group {
                            switch step {
                            case .welcome:
                                WelcomeCard()
                            case .name:
                                NameCard(name: $name, focused: $nameFocused)
                            case .dwelling:
                                DwellingCard(selection: $dwelling)
                            case .hazards:
                                HazardsCard(selection: $hazards)
                            case .complete:
                                CompleteCard(
                                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                    dwelling: dwelling ?? .house,
                                    hazards: SafetyInterest.allCases.filter { hazards.contains($0) }
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .id(step)
                        .transition(.opacity)

                        Group {
                            if step == .welcome {
                                SlideToContinue(
                                    title: "Swipe to Confirm",
                                    enabled: canAdvance,
                                    onComplete: advance
                                )
                            } else {
                                HStack(spacing: 12) {
                                    Button(action: retreat) {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundStyle(Color.white)
                                            .frame(width: footerWidth * 0.20, height: 56)
                                            .background(
                                                Capsule()
                                                    .fill(Color(white: 0.12))
                                            )
                                    }
                                    .buttonStyle(.plain)

                                    Button(action: advance) {
                                        Text(step == .complete ? "Finish" : "Continue")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundStyle(canAdvance ? Color.white : Color(white: 0.55))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 56)
                                            .background(
                                                Capsule()
                                                    .fill(canAdvance ? Color(white: 0.12) : Color(white: 0.82))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!canAdvance)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 36)
                        .padding(.top, 8)
                    }
                    .frame(width: geo.size.width, height: cardHeight + geo.safeAreaInsets.bottom, alignment: .top)
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 28,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 28,
                            style: .continuous
                        )
                        .fill(Color(white: 0.94))
                    )
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 28,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 28,
                            style: .continuous
                        )
                    )
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .preferredColorScheme(.light)
        .animation(.easeInOut(duration: 0.35), value: step)
        .onChange(of: step) { _, new in
            nameFocused = (new == .name)
        }
    }

    private var stepLabel: String {
        switch step {
        case .welcome: return ""
        case .name: return "1 of 3"
        case .dwelling: return "2 of 3"
        case .hazards: return "3 of 3"
        case .complete: return "Done"
        }
    }

    @ViewBuilder
    private func topBand(topHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            if step == .welcome {
                Image("HazardTape")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: topHeight * 0.85)
                    .padding(.top, 8)
            } else if step == .name {
                HStack(alignment: .center, spacing: 10) {
                    ZStack(alignment: .bottom) {
                        Image("HazardBad")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: topHeight * 0.88)

                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Color(red: 0.90, green: 0.22, blue: 0.22))
                            .background(Circle().fill(Color.white).padding(-2))
                            .offset(y: 4)
                    }
                    .frame(maxWidth: .infinity)

                    ZStack(alignment: .bottom) {
                        Image("HazardGood")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: topHeight * 0.88)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Color(red: 0.18, green: 0.70, blue: 0.35))
                            .background(Circle().fill(Color.white).padding(-2))
                            .offset(y: 4)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 14)
                .padding(.top, 2)
                .frame(maxHeight: .infinity, alignment: .top)
            } else if step == .dwelling {
                Image("HomeIllustration")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: topHeight * 0.78)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else if step == .hazards {
                Image("HazardPipes")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: topHeight * 0.92)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            Spacer(minLength: 0)
        }
    }

    private func advance() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if step == .complete {
            onFinished(
                name.trimmingCharacters(in: .whitespacesAndNewlines),
                dwelling ?? .house,
                hazards
            )
            return
        }
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    private func retreat() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard let prev = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        step = prev
    }
}

// MARK: - Slide

private struct SlideToContinue: View {
    let title: String
    let enabled: Bool
    let onComplete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var finished = false
    @GestureState private var dragging = false

    private let height: CGFloat = 60
    private let knob: CGFloat = 52

    var body: some View {
        GeometryReader { geo in
            let maxTravel = max(0, geo.size.width - knob - 8)
            let progress = maxTravel == 0 ? 0 : offset / maxTravel

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(enabled ? Color(white: 0.12) : Color(white: 0.82))

                Capsule()
                    .fill(Color.white.opacity(enabled ? 0.12 : 0))
                    .frame(width: knob + offset + 4)

                Text(finished ? "Let’s go" : title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(enabled ? .white.opacity(0.45 + progress * 0.4) : Color(white: 0.55))
                    .frame(maxWidth: .infinity)
                    .opacity(progress > 0.6 ? 0 : 1)
                    .allowsHitTesting(false)

                Circle()
                    .fill(enabled ? Color.white : Color(white: 0.92))
                    .frame(width: knob, height: knob)
                    .overlay {
                        Image(systemName: finished ? "checkmark" : "chevron.right")
                            .font(.body.weight(.bold))
                            .foregroundStyle(enabled ? Color(white: 0.12) : Color(white: 0.55))
                    }
                    .scaleEffect(dragging && enabled ? 1.04 : 1)
                    .offset(x: 4 + offset)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .updating($dragging) { _, s, _ in s = true }
                            .onChanged { value in
                                guard enabled, !finished else { return }
                                offset = min(max(0, value.translation.width), maxTravel)
                                if offset > maxTravel * 0.94 { finish(maxTravel: maxTravel) }
                            }
                            .onEnded { _ in
                                guard enabled, !finished else { return }
                                if offset > maxTravel * 0.75 {
                                    finish(maxTravel: maxTravel)
                                } else {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                        offset = 0
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }
                    )
            }
        }
        .frame(height: height)
        .allowsHitTesting(enabled)
        .onChange(of: enabled) { _, _ in
            finished = false
            offset = 0
        }
        .onChange(of: title) { _, _ in
            finished = false
            offset = 0
        }
        .accessibilityLabel(title)
    }

    private func finish(maxTravel: CGFloat) {
        guard !finished else { return }
        finished = true
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            offset = maxTravel
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            onComplete()
            finished = false
            offset = 0
        }
    }
}

// MARK: - Cards

private struct WelcomeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image("SafesightWordmark")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 168)
                .frame(height: 26)
                .frame(maxWidth: .infinity)
                .padding(.top, 28)
                .accessibilityLabel("Safesight")

            Text("See what you might have missed.")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(white: 0.1))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 28)

            Text("Point your camera at a room. Safesight finds visible risks and tells you what to fix.")
                .font(.system(size: 16))
                .foregroundStyle(Color(white: 0.4))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.top, 10)

            VStack(spacing: 0) {
                FeatureRow(icon: "viewfinder", title: "One-tap scan", detail: "Capture a photo and get results fast.")
                Divider().padding(.leading, 52)
                FeatureRow(icon: "list.bullet.rectangle", title: "Clear next steps", detail: "Each hazard comes with a simple fix.")
                Divider().padding(.leading, 52)
                FeatureRow(icon: "arrow.triangle.2.circlepath", title: "Rescan to verify", detail: "Check again after you make a change.")
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
            )
            .padding(.horizontal, 24)
            .padding(.top, 28)

            Spacer(minLength: 8)
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(white: 0.15))
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color(white: 0.94)))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(white: 0.12))
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }
}

private struct NameCard: View {
    @Binding var name: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What’s your name?")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(white: 0.1))
                .padding(.horizontal, 24)
                .padding(.top, 8)

            Text("So we can personalize your setup.")
                .font(.system(size: 15))
                .foregroundStyle(Color(white: 0.42))
                .padding(.horizontal, 24)
                .padding(.top, 8)

            TextField("Your first name", text: $name)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color(white: 0.12))
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(white: 0.88))
                )
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused(focused)
                .padding(.horizontal, 24)
                .padding(.top, 24)

            Spacer()
        }
    }
}

private struct DwellingCard: View {
    @Binding var selection: DwellingType?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What are you living in?")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(white: 0.1))
                .padding(.horizontal, 24)
                .padding(.top, 8)

            Text("We’ll weight common hazards for that kind of space.")
                .font(.system(size: 15))
                .foregroundStyle(Color(white: 0.42))
                .padding(.horizontal, 24)
                .padding(.top, 8)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(DwellingType.allCases) { type in
                        SelectRow(
                            icon: type.icon,
                            title: type.rawValue,
                            subtitle: type.subtitle,
                            selected: selection == type
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selection = type
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 8)
            }
        }
    }
}

private struct HazardsCard: View {
    @Binding var selection: Set<SafetyInterest>
    @ObservedObject private var subs = SubscriptionStore.shared

    private var focusLimit: Int? {
        subs.isPremium ? nil : SubscriptionStore.freeFocusLimit
    }

    private var atLimit: Bool {
        guard let focusLimit else { return false }
        return selection.count >= focusLimit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What should we watch for?")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(white: 0.1))
                .padding(.horizontal, 24)
                .padding(.top, 8)

            Text(
                subs.isPremium
                    ? "Select everything that matters in your home."
                    : "Free includes up to \(SubscriptionStore.freeFocusLimit) focus areas: Fire, Water leaks, Electric, Child proofing, Trip hazards, Blocked exits."
            )
                .font(.system(size: 15))
                .foregroundStyle(Color(white: 0.42))
                .padding(.horizontal, 24)
                .padding(.top, 8)

            if !selection.isEmpty {
                Text(
                    focusLimit.map { "\(selection.count) / \($0) selected" }
                        ?? "\(selection.count) selected"
                )
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(white: 0.3))
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
            }

            if selection.count > 8 {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 0.86, green: 0.58, blue: 0.12))
                        .padding(.top, 1)

                    Text("With more than 8 focus areas, the AI model may underperform. For best results, scan in smaller batches.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(white: 0.42))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
            }

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(SafetyInterest.allCases) { hazard in
                        let selected = selection.contains(hazard)
                        let premiumLocked = hazard.requiresPremium && !subs.isPremium
                        let atCap = !selected && atLimit && !premiumLocked
                        let locked = premiumLocked || atCap
                        SelectRow(
                            icon: hazard.icon,
                            title: hazard.rawValue,
                            subtitle: premiumLocked
                                ? "Premium"
                                : (atCap ? "Free limit reached" : nil),
                            selected: selected
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if selected {
                                    selection.remove(hazard)
                                } else if premiumLocked {
                                    Haptics.light()
                                } else if !atLimit {
                                    selection.insert(hazard)
                                } else {
                                    Haptics.light()
                                }
                            }
                        }
                        .opacity(locked && !selected ? 0.45 : 1)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
        }
    }
}

private struct CompleteCard: View {
    let name: String
    let dwelling: DwellingType
    let hazards: [SafetyInterest]

    private var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color(red: 0.18, green: 0.70, blue: 0.35))

                VStack(alignment: .leading, spacing: 2) {
                    Text("You’re all set")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(white: 0.4))
                    Text(firstName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color(white: 0.1))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            Text("Safesight is ready for your \(dwelling.rawValue.lowercased()).")
                .font(.system(size: 16))
                .foregroundStyle(Color(white: 0.42))
                .padding(.horizontal, 24)
                .padding(.top, 16)

            VStack(alignment: .leading, spacing: 14) {
                Text("YOUR FOCUS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Color(white: 0.45))

                ForEach(hazards) { hazard in
                    HStack(spacing: 12) {
                        Image(systemName: hazard.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(white: 0.2))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color(white: 0.94)))

                        Text(hazard.rawValue)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(white: 0.12))
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
            )
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Shared

private struct SelectRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(selected ? .white : Color(white: 0.2))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(selected ? Color(white: 0.14) : Color(white: 0.94)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(white: 0.12))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Color(white: 0.45))
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selected ? Color(white: 0.14) : Color(white: 0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? Color(white: 0.18) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingFlow()
}
