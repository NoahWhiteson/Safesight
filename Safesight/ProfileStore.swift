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

    private let key = "safesight.userProfile"

    var hasCompletedOnboarding: Bool { profile != nil }

    init() {
        load()
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
