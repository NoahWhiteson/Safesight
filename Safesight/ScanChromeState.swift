//
//  ScanChromeState.swift
//  Safesight
//
//  Immersive scan chrome — hides the UIKit tab bar while analyzing.
//

import Combine
import Foundation

@MainActor
final class ScanChromeState: ObservableObject {
    static let shared = ScanChromeState()

    @Published var hidesTabBar = false
}
