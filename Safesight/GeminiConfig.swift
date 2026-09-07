//
//  GeminiConfig.swift
//  Safesight
//
//  API key lives in GeminiSecrets.plist (gitignored). Copy
//  GeminiSecrets.example.plist → GeminiSecrets.plist and paste your key.
//

import Foundation

enum GeminiConfig {
    /// Google AI / Gemini API key (from local GeminiSecrets.plist).
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

    /// Gemini 3.8 Flash — vision + structured JSON for room scans.
    static let model = "gemini-3.8-flash"

    static var generateContentURL: URL {
        URL(string:
            "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        )!
    }
}
