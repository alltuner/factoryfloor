// ABOUTME: Tracks which workstreams have recent terminal output activity.
// ABOUTME: Publishes a set of active workstream IDs for use by the sidebar.

import Combine
import Foundation

@MainActor
final class WorkstreamActivityTracker: ObservableObject {
    @Published private(set) var activeWorkstreamIDs: Set<UUID> = []
    @Published private(set) var needsAttentionIDs: Set<UUID> = []

    /// How long after the last activity a workstream is considered active.
    private let activityTimeout: TimeInterval = 5

    private var lastActivityTimes: [UUID: Date] = [:]
    private var cancellables: Set<AnyCancellable> = []
    private var pruneTimer: AnyCancellable?

    init() {
        NotificationCenter.default.publisher(for: .terminalTitleChanged)
            .compactMap { $0.object as? UUID }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] wsID in
                self?.recordActivity(for: wsID)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .terminalNeedsAttention)
            .compactMap { $0.object as? UUID }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] wsID in
                self?.recordAttention(for: wsID)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .terminalClearAttention)
            .compactMap { $0.object as? UUID }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] wsID in
                self?.clearAttention(for: wsID)
            }
            .store(in: &cancellables)

        pruneTimer = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.pruneExpired()
            }
    }

    private func recordActivity(for workstreamID: UUID) {
        lastActivityTimes[workstreamID] = Date()
        if !activeWorkstreamIDs.contains(workstreamID) {
            activeWorkstreamIDs.insert(workstreamID)
        }
    }

    private func recordAttention(for workstreamID: UUID) {
        if !needsAttentionIDs.contains(workstreamID) {
            needsAttentionIDs.insert(workstreamID)
            objectWillChange.send()
        }
    }

    func clearAttention(for workstreamID: UUID) {
        if needsAttentionIDs.remove(workstreamID) != nil {
            objectWillChange.send()
        }
    }

    private func pruneExpired() {
        let cutoff = Date().addingTimeInterval(-activityTimeout)
        var changed = false
        for (id, time) in lastActivityTimes where time < cutoff {
            lastActivityTimes.removeValue(forKey: id)
            if activeWorkstreamIDs.remove(id) != nil {
                changed = true
            }
        }
        // Force publish even if the Set reference didn't change
        if changed {
            objectWillChange.send()
        }
    }

    func isActive(_ workstreamID: UUID) -> Bool {
        activeWorkstreamIDs.contains(workstreamID)
    }

    func needsAttention(_ workstreamID: UUID) -> Bool {
        needsAttentionIDs.contains(workstreamID)
    }
}
