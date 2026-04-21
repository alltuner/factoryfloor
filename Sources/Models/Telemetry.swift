// ABOUTME: Sends anonymous usage telemetry to a self-hosted Umami instance.
// ABOUTME: Tracks app launches and basic system info. No private data is collected.

import AppKit
import Foundation
import os

@MainActor
final class Telemetry {
    static let shared = Telemetry()

    private let logger = Logger(subsystem: "com.alltuner.factoryfloor", category: "telemetry")
    private let endpoint = URL(string: "https://meta.factory-floor.com/api/send")!
    private let websiteID = "0ad50276-0a54-4b71-b3f2-b953326a9452"
    private let hostname = "app.factory-floor.com"

    var isEnabled: Bool {
        #if DEBUG
            return false
        #else
            return UserDefaults.standard.object(forKey: "factoryfloor.telemetryEnabled") as? Bool ?? true
        #endif
    }

    /// Anonymous installation identifier, generated on first launch.
    var installationID: String {
        let key = "factoryfloor.installationID"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    func trackLaunch() {
        track("app_launch", url: "/app/launch", title: "App Launch", data: systemInfo())
    }

    func track(_ event: String, url: String = "/app", title: String? = nil, data: [String: String] = [:]) {
        guard isEnabled else { return }

        let screen = NSScreen.main?.frame.size
        let userAgent = Self.userAgent
        let id = installationID

        Task.detached { [endpoint, websiteID, hostname, logger] in
            var payload: [String: Any] = [
                "hostname": hostname,
                "language": Locale.current.identifier,
                "url": url,
                "website": websiteID,
                "name": event,
                "id": id,
            ]

            if let title {
                payload["title"] = title
            }

            if let screen {
                payload["screen"] = "\(Int(screen.width))x\(Int(screen.height))"
            }

            if !data.isEmpty {
                payload["data"] = data
            }

            let body: [String: Any] = [
                "type": "event",
                "payload": payload,
            ]

            guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 5
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            request.httpBody = jsonData

            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    logger.debug("Telemetry request failed with status \(http.statusCode)")
                }
            } catch {
                logger.debug("Telemetry request failed: \(error.localizedDescription)")
            }
        }
    }

    private func systemInfo() -> [String: String] {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return [
            "version": AppConstants.version,
            "os_version": "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            "locale": Locale.current.identifier,
        ]
    }

    private static let userAgent: String = {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let osVersion = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        #if arch(arm64)
            let arch = "arm64"
        #elseif arch(x86_64)
            let arch = "x86_64"
        #else
            let arch = "unknown"
        #endif
        let locale = Locale.current.identifier
        return "FactoryFloor/\(AppConstants.version) (Macintosh; macOS \(osVersion); \(arch); \(locale))"
    }()
}
