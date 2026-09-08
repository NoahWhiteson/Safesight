//
//  SafesightAPIConfig.swift
//  Safesight
//
//  Points the app at the Safesight server (Gemini key lives on the server).
//

import Foundation

enum SafesightAPIConfig {
    /// Production API. Override via Info.plist `SAFESIGHT_API_BASE_URL` for local/dev.
    static var baseURL: URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "SAFESIGHT_API_BASE_URL") as? String,
           let url = URL(string: raw), !raw.isEmpty {
            return url
        }
        return URL(string: "https://safesight.noahwhiteson.com")!
    }

    /// Shared with server `SAFESIGHT_API_SECRET`. Load from local plist (gitignored).
    static var apiSecret: String {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "SAFESIGHT_API_SECRET") as? String,
           !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard
            let url = Bundle.main.url(forResource: "SafesightAPISecrets", withExtension: "plist"),
            let dict = NSDictionary(contentsOf: url),
            let key = dict["API_SECRET"] as? String
        else {
            return ""
        }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var analyzeURL: URL {
        baseURL.appendingPathComponent("v1/analyze")
    }

    static var healthURL: URL {
        baseURL.appendingPathComponent("health")
    }
}
