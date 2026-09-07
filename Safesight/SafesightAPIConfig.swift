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

    static var analyzeURL: URL {
        baseURL.appendingPathComponent("v1/analyze")
    }

    static var healthURL: URL {
        baseURL.appendingPathComponent("health")
    }
}
