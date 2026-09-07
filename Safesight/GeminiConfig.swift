//
//  GeminiConfig.swift
//  Safesight
//
//  Gemini runs on the Safesight server now. This file is kept only for
//  optional local/debug tooling — the app scan path uses SafesightAPIConfig.
//

import Foundation

enum GeminiConfig {
    /// Prefer server-side key (`server/.env`). Local plist is legacy/debug only.
    static var apiKey: String {
        guard
            let url = Bundle.main.url(forResource: "GeminiSecrets", withExtension: "plist"),
            let dict = NSDictionary(contentsOf: url),
            let key = dict["API_KEY"] as? String
        else {
            return ""
        }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static let model = "gemini-3.8-flash"

    static var generateContentURL: URL {
        URL(string:
            "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        )!
    }
}
