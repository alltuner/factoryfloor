// ABOUTME: NSViewRepresentable that bridges a TerminalView into SwiftUI.
// ABOUTME: Manages the lifecycle of terminal surfaces per workstream, caching them for fast switching.

import SwiftUI

extension Notification.Name {
    static let terminalSurfaceClosed = Notification.Name("ff2.terminalSurfaceClosed")
}

struct TerminalContainerView: NSViewRepresentable {
    let workstreamID: UUID
    let workingDirectory: String
    let projectName: String
    let workstreamName: String

    @EnvironmentObject var surfaceCache: TerminalSurfaceCache

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        guard let app = TerminalApp.shared.app else { return }

        let envVars = [
            "FF_PROJECT": projectName,
            "FF_WORKSTREAM": workstreamName,
        ]

        let terminalView = surfaceCache.surface(
            for: workstreamID,
            app: app,
            workingDirectory: workingDirectory,
            environmentVars: envVars
        )

        // Only re-add if the terminal view changed
        if terminalView.superview !== container {
            container.subviews.forEach { $0.removeFromSuperview() }
            container.addSubview(terminalView)
            terminalView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                terminalView.topAnchor.constraint(equalTo: container.topAnchor),
                terminalView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                terminalView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                terminalView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ])
        }

        DispatchQueue.main.async {
            terminalView.setFocused(true)
        }
    }
}

/// Caches terminal surfaces so switching workstreams doesn't destroy/recreate them.
/// When a terminal exits, removes the old surface and triggers a SwiftUI update to recreate it.
final class TerminalSurfaceCache: ObservableObject {
    private var surfaces: [UUID: TerminalView] = [:]
    private var surfaceParams: [UUID: SurfaceParams] = [:]

    struct SurfaceParams {
        let workingDirectory: String
        let environmentVars: [String: String]
    }

    init() {
        NotificationCenter.default.addObserver(
            forName: .terminalSurfaceClosed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, let closedView = notification.object as? TerminalView else { return }
            self.handleSurfaceClosed(closedView)
        }
    }

    func surface(for workstreamID: UUID, app: ghostty_app_t, workingDirectory: String, environmentVars: [String: String] = [:]) -> TerminalView {
        if let existing = surfaces[workstreamID] {
            existing.workstreamID = workstreamID
            return existing
        }
        let view = TerminalView(app: app, workingDirectory: workingDirectory, environmentVars: environmentVars)
        view.workstreamID = workstreamID
        surfaces[workstreamID] = view
        surfaceParams[workstreamID] = SurfaceParams(workingDirectory: workingDirectory, environmentVars: environmentVars)
        return view
    }

    func removeSurface(for workstreamID: UUID) {
        surfaces.removeValue(forKey: workstreamID)
        surfaceParams.removeValue(forKey: workstreamID)
    }

    private func handleSurfaceClosed(_ closedView: TerminalView) {
        guard let (wsID, _) = surfaces.first(where: { $0.value === closedView }) else { return }
        guard let params = surfaceParams[wsID],
              let app = TerminalApp.shared.app else { return }

        // Remove old surface and recreate
        surfaces.removeValue(forKey: wsID)
        let newView = TerminalView(app: app, workingDirectory: params.workingDirectory, environmentVars: params.environmentVars)
        newView.workstreamID = wsID
        surfaces[wsID] = newView

        // Trigger SwiftUI update
        objectWillChange.send()
    }
}
