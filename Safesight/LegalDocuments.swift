//
//  LegalDocuments.swift
//  Safesight
//

import SwiftUI

enum LegalDocument: String, Identifiable {
    case terms
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms: return "Terms of Service"
        case .privacy: return "Privacy Policy"
        }
    }
}

struct LegalDocumentSheet: View {
    let document: LegalDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(document == .terms ? LegalCopy.terms : LegalCopy.privacy)
                    .font(.system(size: 15))
                    .foregroundStyle(Color(white: 0.2))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .background(Color(red: 0.96, green: 0.96, blue: 0.97).ignoresSafeArea())
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        Haptics.light()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

enum LegalCopy {
    static let terms = """
    Terms of Service
    Last updated: September 7, 2026

    These Terms of Service (“Terms”) govern your use of the Safesight mobile application and related services (the “App”) operated by Noah Whiteson (“we,” “us,” or “our”). By downloading, accessing, or using Safesight, you agree to these Terms. If you do not agree, do not use the App.

    1. What Safesight is
    Safesight helps you review photos of indoor spaces for visible home-safety risks using automated analysis. It is a consumer assistance tool. It is not a professional home inspection, engineering assessment, insurance evaluation, code-compliance review, or emergency service.

    2. Eligibility
    You must be able to form a binding contract where you live. If you are under the age of majority, a parent or legal guardian must agree to these Terms on your behalf. Shipaton Next Gen entrants under the age of majority must also follow applicable contest consent rules.

    3. Accounts and device data
    Safesight stores profile, scan history, and related preferences on your device. You are responsible for activity on your device and for keeping any API or configuration secrets you use for development secure.

    4. Acceptable use
    You agree not to: misuse the App; attempt to disrupt servers or bypass rate limits or authentication; reverse engineer the App except where allowed by law; use Safesight to provide regulated inspection services to others as if it were certified; or upload content you do not have the right to use.

    5. AI analysis and accuracy
    Hazard labels, bounding boxes, confidence percentages, summaries, House Scores, and product suggestions are generated or assisted by machine learning models and may be incomplete, incorrect, outdated, or misleading. Confidence values are the model’s self-reported certainty, not measured laboratory accuracy. You remain responsible for verifying conditions in person and for any actions you take.

    6. Subscriptions and purchases
    Optional Premium subscriptions and in-app purchases are processed through Apple and RevenueCat. Pricing, trials, renewals, and cancellations follow Apple’s terms and the App Store listing. Restore purchases from the You tab if you reinstall. Free tier limits (including scan counts and focus areas) may change.

    7. Product recommendations
    Suggested products are informational only. We do not guarantee availability, price, fitness for purpose, or safety of third-party goods. Purchases on third-party sites are solely between you and that seller.

    8. Intellectual property
    The App, branding, and original content are owned by us or our licensors. The project source may be released under open-source licenses (including GPL-3.0) as stated in the public repository; your use of distributed source is also subject to those licenses.

    9. Disclaimer of warranties
    THE APP IS PROVIDED “AS IS” AND “AS AVAILABLE” WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT. WE DO NOT WARRANT THAT ANALYSES WILL BE ACCURATE, COMPLETE, OR ERROR-FREE.

    10. Limitation of liability
    TO THE MAXIMUM EXTENT PERMITTED BY LAW, WE ARE NOT LIABLE FOR INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR FOR PERSONAL INJURY, PROPERTY DAMAGE, OR LOSS ARISING FROM RELIANCE ON THE APP. OUR TOTAL LIABILITY FOR ANY CLAIM RELATING TO THE APP WILL NOT EXCEED THE GREATER OF (A) AMOUNTS YOU PAID US FOR PREMIUM IN THE 12 MONTHS BEFORE THE CLAIM OR (B) USD $50.

    11. Indemnity
    You agree to indemnify and hold us harmless from claims arising out of your misuse of the App, your violation of these Terms, or your reliance on App outputs without independent verification.

    12. Changes
    We may update these Terms. Continued use after changes means you accept the updated Terms. Material changes may be noted in the App or repository documentation.

    13. Contact
    Questions about these Terms: noahwhiteson5@gmail.com
    """

    static let privacy = """
    Privacy Policy
    Last updated: September 7, 2026

    This Privacy Policy explains how Safesight (“we,” “us”) handles information when you use the Safesight iOS app.

    1. Summary
    Scan photos used for analysis are sent to our Safesight API so a vision model can return structured results. Profile data, scan history, and images we keep for your gallery are stored on your device. We do not sell your personal information.

    2. Information we process
    • Profile details you enter (for example name, dwelling type, focus areas, look-hardness settings).
    • Photos you capture or upload for a scan, plus analysis results (hazards, boxes, scores, summaries).
    • Subscription status and purchase-related identifiers via Apple and RevenueCat.
    • Basic technical data needed to operate the API (such as IP address for rate limiting, and request metadata).

    3. How we use information
    • To analyze rooms and show hazards, scores, and recommendations in the App.
    • To enforce free-tier limits and Premium entitlements.
    • To operate, secure, and debug the API (including rate limits and abuse prevention).
    • To improve prompts, schemas, and product quality using aggregated or de-identified operational signals where feasible.

    4. Where analysis runs
    When you scan, the image and selected focus metadata are transmitted to the Safesight API (hosted or a server you configure). The API calls a third-party vision provider (Google Gemini) to generate structured JSON. Do not scan images you are not allowed to share with these processors.

    5. On-device storage
    Scan images and history are stored locally on your device for the gallery and Hazards features. Unstarred scans may be purged after a retention period described in the App. Logging out can erase local Safesight data on that device.

    6. Third parties
    • Apple — App distribution, notifications permissions, and In-App Purchases.
    • RevenueCat — subscription status and Customer Center.
    • Google Gemini (via our API) — vision analysis of scan images.
    • Product link destinations (for example Amazon search pages) if you choose to open recommendations.
    Their policies apply when you use those services.

    7. Data retention
    API requests are processed to return a result and to apply security controls (such as rate limits). We do not operate a consumer “cloud gallery” of your scans in the App’s default design; your gallery is on-device. Server logs may retain limited technical data for a short operational period.

    8. Children
    Safesight is not directed at children under 13. If you believe we processed a child’s data inappropriately, contact us and we will take reasonable steps to delete it.

    9. Your choices
    • Limit photos you upload; use focus areas thoughtfully.
    • Delete local history via log out / clear flows in the App.
    • Manage Premium through Apple subscription settings / RevenueCat Customer Center.
    • Decline camera or photo library permission (upload/capture features will not work).

    10. Security
    We use transport encryption (HTTPS) for API calls and keep production API secrets off public source control. No method of transmission or storage is 100% secure.

    11. International users
    If you use Safesight from outside the United States, you understand information may be processed in the U.S. or other countries where our providers operate.

    12. Changes
    We may update this Policy. The “Last updated” date will change when we do. Continued use means you accept the updated Policy.

    13. Contact
    Privacy questions: noahwhiteson5@gmail.com
    """
}
