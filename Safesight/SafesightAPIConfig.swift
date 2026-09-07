//
//  SafesightAPIConfig.swift
//  Safesight
//
//  Points the app at the Safesight server (Gemini key lives on the server).
//

import Foundation

enum SafesightAPIConfig {
    /// Override with your Mac’s LAN IP when testing on a physical device.
    /// Simulator can use loopback.
    static var baseURL: URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "SAFESIGHT_API_BASE_URL") as? String,
           let url = URL(string: raw), !raw.isEmpty {
            return url
        }
#if targetEnvironment(simulator)
        return URL(string: "http://127.0.0.1:8787")!
#else
        // Change to your machine IP if needed, e.g. http://192.168.1.20:8787
        return URL(string: "http://127.0.0.1:8787")!
#endif
    }

    static var analyzeURL: URL {
        baseURL.appendingPathComponent("v1/analyze")
    }

    static var healthURL: URL {
        baseURL.appendingPathComponent("health")
    }
}
