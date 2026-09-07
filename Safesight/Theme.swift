//
//  Theme.swift
//  Safesight
//

import SwiftUI
import UIKit

enum Theme {
    static let bg = Color(red: 0.96, green: 0.96, blue: 0.97)
    static let ink = Color(white: 0.08)
    static let mute = Color(white: 0.45)
    static let soft = Color(white: 0.94)
    static let blue = Color(red: 0.0, green: 0.48, blue: 1.0)
    static let good = Color(red: 0.22, green: 0.72, blue: 0.48)
    static let warn = Color(red: 0.92, green: 0.35, blue: 0.32)
}

enum Haptics {
    static func select() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
