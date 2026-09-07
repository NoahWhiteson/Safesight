//
//  ProfileStore.swift
//  Safesight
//

import Combine
import Foundation
import SwiftUI

struct UserProfile: Codable, Equatable {
    var name: String
    var dwellingRaw: String
    var hazardRaws: [String]

    var dwelling: DwellingType {
        DwellingType(rawValue: dwellingRaw) ?? .house
    }

    var hazards: [SafetyInterest] {
        hazardRaws.compactMap { SafetyInterest(rawValue: $0) }
    }

    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}

@MainActor
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    @Published private(set) var profile: UserProfile?
    /// 0.1 = barely look · 1.0 = very aggressive. Default mid.
    @Published private(set) var scanAggressiveness: Double = 0.55

    private let key = "safesight.userProfile"
    private let aggressivenessKey = "safesight.scanAggressiveness"

    var hasCompletedOnboarding: Bool { profile != nil }

    init() {
        load()
        let stored = UserDefaults.standard.object(forKey: aggressivenessKey) as? Double
        scanAggressiveness = Self.clampAggressiveness(stored ?? 0.55)
    }

    func setScanAggressiveness(_ value: Double) {
        let next = Self.clampAggressiveness(value)
        guard next != scanAggressiveness else { return }
        scanAggressiveness = next
        UserDefaults.standard.set(next, forKey: aggressivenessKey)
    }

    static func clampAggressiveness(_ value: Double) -> Double {
        min(1.0, max(0.1, value))
    }

    /// How many hazards Gemini may return at this aggressiveness (2…8).
    var maxHazardsPerScan: Int {
        Int(round(2.0 + scanAggressiveness * 6.0))
    }

    func save(name: String, dwelling: DwellingType, hazards: Set<SafetyInterest>) {
        let sortedHazards = SafetyInterest.allCases
            .filter { hazards.contains($0) }
            .map(\.rawValue)
        let next = UserProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            dwellingRaw: dwelling.rawValue,
            hazardRaws: sortedHazards
        )
        profile = next
        if let data = try? JSONEncoder().encode(next) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func updateHazards(_ hazards: Set<SafetyInterest>) {
        guard var current = profile else { return }
        current.hazardRaws = SafetyInterest.allCases
            .filter { hazards.contains($0) }
            .map(\.rawValue)
        profile = current
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func updateDwelling(_ dwelling: DwellingType) {
        guard var current = profile else { return }
        current.dwellingRaw = dwelling.rawValue
        profile = current
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            profile = nil
            return
        }
        profile = decoded
    }

    func reset() {
        profile = nil
        UserDefaults.standard.removeObject(forKey: key)
    }
}
