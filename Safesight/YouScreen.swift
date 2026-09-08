//
//  YouScreen.swift
//  Safesight
//

import SwiftUI
import RevenueCatUI
import UIKit


struct YouScreen: View {
    let profile: UserProfile
    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var subs = SubscriptionStore.shared
    @State private var showPaywall = false
    @State private var showCustomerCenter = false
    @State private var showEditFocus = false
    @State private var showEditDwelling = false
    @State private var showLogoutConfirm = false
    @State private var legalDocument: LegalDocument?

    private var current: UserProfile {
        profiles.profile ?? profile
    }

    private var planLabel: String {
        subs.isPremium ? "Premium" : "Free"
    }

    private var planDetail: String {
        if subs.isPremium {
            return "Full access · all focus areas"
        }
        return "\(SubscriptionStore.freeScanLimit) scans · 6 focus areas"
    }

    private var scansLabel: String {
        if subs.isPremium {
            return "\(subs.scanCount) (unlimited)"
        }
        return "\(subs.scanCount) / \(SubscriptionStore.freeScanLimit)"
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    profileHeader

                    planCard
                        .padding(.horizontal, 22)

                    settingsSection(title: "Home profile") {
                        Button {
                            Haptics.light()
                            showEditDwelling = true
                        } label: {
                            settingsRow(
                                icon: "house.fill",
                                title: "Dwelling",
                                value: current.dwelling.rawValue,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)

                        settingsRow(icon: "viewfinder", title: "Scans used", value: scansLabel)
                        settingsRow(
                            icon: "scope",
                            title: "Focus areas",
                            value: "\(current.hazards.count)"
                        )
                    }
                    .padding(.horizontal, 22)

                    lookHardnessCard
                        .padding(.horizontal, 22)

                    focusSection
                        .padding(.horizontal, 22)

                    settingsSection(title: "Subscription") {
                        Button {
                            Haptics.light()
                            if subs.isPremium {
                                showCustomerCenter = true
                            } else {
                                showPaywall = true
                            }
                        } label: {
                            settingsRow(
                                icon: subs.isPremium ? "crown.fill" : "crown",
                                title: subs.isPremium ? "Manage subscription" : "Upgrade to Premium",
                                value: nil,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            Haptics.light()
                            Task { _ = await subs.restorePurchases() }
                        } label: {
                            settingsRow(
                                icon: "arrow.clockwise",
                                title: "Restore purchases",
                                value: nil,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 22)

                    settingsSection(title: "Account") {
                        Button {
                            Haptics.warning()
                            showLogoutConfirm = true
                        } label: {
                            settingsRow(
                                icon: "rectangle.portrait.and.arrow.right",
                                title: "Log out",
                                value: nil,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 22)

                    if let err = subs.lastErrorMessage {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.warn)
                            .padding(.horizontal, 22)
                    }

                    legalFooter
                        .padding(.horizontal, 22)
                        .padding(.top, 12)
                }
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.bg)
            .navigationTitle("You")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.automatic, for: .navigationBar)
            .containerBackground(Theme.bg, for: .navigation)
            .sheet(isPresented: $showPaywall) {
                PaywallView(isModal: true)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
            .sheet(isPresented: $showCustomerCenter) {
                CustomerCenterView()
            }
            .sheet(isPresented: $showEditFocus) {
                EditFocusAreasSheet(
                    initial: Set(current.hazards),
                    isPremium: subs.isPremium,
                    onUpgrade: {
                        showEditFocus = false
                        showPaywall = true
                    }
                )
            }
            .sheet(isPresented: $showEditDwelling) {
                EditDwellingSheet(initial: current.dwelling)
            }
            .sheet(item: $legalDocument) { doc in
                LegalDocumentSheet(document: doc)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
            .confirmationDialog(
                "Log out?",
                isPresented: $showLogoutConfirm,
                titleVisibility: .visible
            ) {
                Button("Log out", role: .destructive) {
                    Haptics.warning()
                    performLogout()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You can lose your data. Scans, house score, and profile on this device will be erased. This can’t be undone.")
            }
            .onAppear {
                Task { await subs.refresh() }
            }
        }
    }

    private func performLogout() {
        ScanHistoryStore.shared.clearAll()
        SubscriptionStore.shared.resetLocalProgress()
        AppNavigation.shared.selectedTab = 0
        AppNavigation.shared.pendingScanID = nil
        profiles.logout()
    }

    private var legalFooter: some View {
        VStack(spacing: 14) {
            Text("Safesight can miss hazards. This app is an assistant for visible risks, not a professional inspection, insurance assessment, or emergency service. Always use your own judgment.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.mute)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 20) {
                Button("Terms of Service") {
                    Haptics.light()
                    legalDocument = .terms
                }
                .buttonStyle(.plain)

                Button("Privacy Policy") {
                    Haptics.light()
                    legalDocument = .privacy
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.blue)

            Text("Safesight")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.mute)
        }
        .frame(maxWidth: .infinity)
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            ProfileAvatarView(name: current.name, size: 96)
            Text(current.name)
                .font(.system(size: 22, weight: .bold))
            Text(current.dwelling.rawValue)
                .font(.system(size: 15))
                .foregroundStyle(Theme.mute)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your plan")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.mute)
                    Text(planLabel)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(planDetail)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.mute)
                }
                Spacer()
                Image(systemName: subs.isPremium ? "checkmark.circle.fill" : "crown.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        subs.isPremium
                            ? Color(red: 0.18, green: 0.70, blue: 0.35)
                            : Theme.blue
                    )
            }

            Button {
                Haptics.medium()
                if subs.isPremium {
                    showCustomerCenter = true
                } else {
                    showPaywall = true
                }
            } label: {
                Text(subs.isPremium ? "Manage subscription" : "Upgrade to Premium")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Capsule().fill(Theme.ink))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
    }

    private var lookHardnessCard: some View {
        let percent = Int(round(profiles.scanAggressiveness * 100))
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Look hardness")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.mute)
                Text("\(percent)%")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.blue)
                    .monospacedDigit()
                Spacer()
            }

            Text(lookHardnessCaption(percent))
                .font(.system(size: 13))
                .foregroundStyle(Theme.mute)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                HStack {
                    Text("Barely look")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.mute)
                    Spacer()
                    Text("Look hard")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.mute)
                }

                PixelLookSlider(
                    value: Binding(
                        get: { profiles.scanAggressiveness },
                        set: { profiles.setScanAggressiveness($0) }
                    )
                )
            }

            Text("Up to \(profiles.maxHazardsPerScan) hazards per photo at this setting.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.mute)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
    }

    private func lookHardnessCaption(_ percent: Int) -> String {
        switch percent {
        case ..<35:
            return "Only clear, obvious issues. Fewer false alarms."
        case ..<70:
            return "Balanced — clear hazards plus likely fixes a careful homeowner should catch."
        default:
            return "Aggressive — surfaces borderline and preventive risks in your focus areas."
        }
    }

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("FOCUS AREAS")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.mute)
                Spacer()
                Button {
                    Haptics.light()
                    showEditFocus = true
                } label: {
                    Text("Edit")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                let hazards = Array(current.hazards)
                if hazards.isEmpty {
                    Text("No focus areas yet. Tap Edit to choose what Safesight watches for.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.mute)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    let visible = Array(hazards.prefix(6))
                    let others = max(0, hazards.count - 6)

                    ForEach(visible) { hazard in
                        HStack(spacing: 12) {
                            Image(systemName: hazard.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.blue)
                                .frame(width: 28)
                            Text(hazard.rawValue)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Spacer(minLength: 0)
                            if hazard.requiresPremium {
                                Text("Premium")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Theme.blue.opacity(0.12)))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    if others > 0 {
                        HStack(spacing: 12) {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.blue)
                                .frame(width: 28)
                            Text("\(others) other Focus Areas Selected")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
            )

            if current.hazards.count > 8 {
                focusBatchWarning
            }
        }
    }

    private var focusBatchWarning: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 0.86, green: 0.58, blue: 0.12))
                .padding(.top, 1)

            Text("With more than 8 focus areas, the AI model may underperform. For best results, scan in smaller batches.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.mute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.mute)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
            )
        }
    }

    private func settingsRow(
        icon: String,
        title: String,
        value: String?,
        showsChevron: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.blue)
                .frame(width: 28)

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)

            Spacer(minLength: 8)

            if let value {
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.mute)
                    .lineLimit(1)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.mute.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

struct EditFocusAreasSheet: View {
    let initial: Set<SafetyInterest>
    let isPremium: Bool
    var onUpgrade: () -> Void

    @ObservedObject private var profiles = ProfileStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<SafetyInterest> = []

    private var focusLimit: Int? {
        isPremium ? nil : SubscriptionStore.freeFocusLimit
    }

    private var atLimit: Bool {
        guard let focusLimit else { return false }
        return selection.count >= focusLimit
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(SafetyInterest.allCases) { hazard in
                        let selected = selection.contains(hazard)
                        let premiumLocked = hazard.requiresPremium && !isPremium
                        let capped = !selected && atLimit && !premiumLocked

                        Button {
                            Haptics.select()
                            if selected {
                                selection.remove(hazard)
                            } else if premiumLocked {
                                onUpgrade()
                            } else if !atLimit {
                                selection.insert(hazard)
                            } else {
                                Haptics.light()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: hazard.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.blue)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(hazard.rawValue)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Theme.ink)
                                    if premiumLocked {
                                        Text("Premium focus area")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Theme.mute)
                                    } else if capped {
                                        Text("Free limit reached")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Theme.mute)
                                    }
                                }

                                Spacer()

                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(
                                        selected
                                            ? Color(red: 0.18, green: 0.70, blue: 0.35)
                                            : Color(white: 0.75)
                                    )
                            }
                            .opacity((premiumLocked || capped) && !selected ? 0.5 : 1)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(
                        isPremium
                            ? "Select everything that matters"
                            : "Free: Fire, Water leaks, Electric, Child proofing, Trip hazards, Blocked exits (max \(SubscriptionStore.freeFocusLimit))."
                    )
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        if let focusLimit {
                            Text("\(selection.count) / \(focusLimit) selected")
                        } else {
                            Text("\(selection.count) selected")
                        }

                        if selection.count > 8 {
                            Text("With more than 8 focus areas, the AI model may underperform. For best results, scan in smaller batches.")
                                .foregroundStyle(Color(red: 0.72, green: 0.48, blue: 0.08))
                        }
                    }
                }
            }
            .navigationTitle("Focus areas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        Haptics.light()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Haptics.medium()
                        var next = selection
                        if !isPremium {
                            next = Set(next.filter { !$0.requiresPremium })
                            let ordered = SafetyInterest.freeCases.filter { next.contains($0) }
                            next = Set(ordered.prefix(SubscriptionStore.freeFocusLimit))
                        }
                        profiles.updateHazards(next)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selection.isEmpty)
                }
            }
            .onAppear {
                selection = initial
            }
        }
    }
}

struct EditDwellingSheet: View {
    let initial: DwellingType

    @ObservedObject private var profiles = ProfileStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selection: DwellingType = .house

    var body: some View {
        NavigationStack {
            List {
                Section("Where do you live?") {
                    ForEach(DwellingType.allCases) { dwelling in
                        Button {
                            Haptics.select()
                            selection = dwelling
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: dwelling.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.blue)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dwelling.rawValue)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Theme.ink)
                                    Text(dwelling.subtitle)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.mute)
                                }

                                Spacer()

                                Image(systemName: selection == dwelling ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(
                                        selection == dwelling
                                            ? Color(red: 0.18, green: 0.70, blue: 0.35)
                                            : Color(white: 0.75)
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Home profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        Haptics.light()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Haptics.medium()
                        profiles.updateDwelling(selection)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                selection = initial
            }
        }
    }
}
