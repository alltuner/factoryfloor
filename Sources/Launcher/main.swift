// ABOUTME: Runs an interactive command, detects listening TCP ports, and reports run state.
// ABOUTME: Keeps terminal stdio attached while the app retargets browsers from a state file.

import Foundation
import Darwin

do {
    let configuration = try Configuration(arguments: CommandLine.arguments)
    try Launcher(configuration: configuration).run()
} catch let error as LauncherError {
    FileHandle.standardError.write(Data((error.message + "\n").utf8))
    exit(error.exitCode)
} catch {
    FileHandle.standardError.write(Data(("ff-run failed: \(error.localizedDescription)\n").utf8))
    exit(1)
}

private struct Launcher {
    let configuration: Configuration

    func run() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: configuration.command[0])
        process.arguments = Array(configuration.command.dropFirst())
        process.environment = ProcessInfo.processInfo.environment

        try process.run()
        _ = setpgid(process.processIdentifier, process.processIdentifier)

        try writeState(
            pid: process.processIdentifier,
            status: .starting,
            detectedPorts: [],
            selectedPort: nil,
            startedAt: configuration.startedAt
        )

        let scanner = PortScanner(pid: process.processIdentifier, expectedPort: configuration.expectedPort)
        let signals = installSignalForwarders(for: process.processIdentifier)
        scanner.start(startedAt: configuration.startedAt, workstreamID: configuration.workstreamID)

        process.waitUntilExit()

        scanner.stop()
        signals.forEach { $0.cancel() }

        let finalStatus: RunStateStatus
        let exitCode: Int32
        switch process.terminationReason {
        case .exit:
            exitCode = process.terminationStatus
            finalStatus = exitCode == 0 ? .stopped : .crashed
        case .uncaughtSignal:
            exitCode = 128 + process.terminationStatus
            finalStatus = .crashed
        @unknown default:
            exitCode = 1
            finalStatus = .crashed
        }

        try? writeState(
            pid: process.processIdentifier,
            status: finalStatus,
            detectedPorts: scanner.detectedPorts,
            selectedPort: scanner.selectedPort,
            startedAt: configuration.startedAt
        )
        RunStateStore.remove(for: configuration.workstreamID)
        exit(exitCode)
    }

    private func installSignalForwarders(for childPID: Int32) -> [DispatchSourceSignal] {
        var sources: [DispatchSourceSignal] = []
        let queue = DispatchQueue(label: "factoryfloor.ff-run.signals")
        for signalNumber in [SIGINT, SIGTERM] {
            signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: queue)
            source.setEventHandler {
                _ = kill(-childPID, signalNumber)
            }
            source.resume()
            sources.append(source)
        }
        return sources
    }

    private func writeState(pid: Int32, status: RunStateStatus, detectedPorts: [Int], selectedPort: Int?, startedAt: Date) throws {
        let state = RunStateSnapshot(
            pid: pid,
            status: status,
            detectedPorts: detectedPorts.sorted(),
            selectedPort: selectedPort,
            startedAt: startedAt
        )
        try RunStateStore.write(state, for: configuration.workstreamID)
    }
}

private final class PortScanner: @unchecked Sendable {
    private let pid: Int32
    private let queue = DispatchQueue(label: "factoryfloor.ff-run.scanner")
    private var timer: DispatchSourceTimer?
    private var tracker: PortSelectionTracker
    private(set) var detectedPorts: [Int] = []
    private(set) var selectedPort: Int?
    private var pollCount = 0
    private var active = false

    init(pid: Int32, expectedPort: Int?) {
        self.pid = pid
        self.tracker = PortSelectionTracker(expectedPort: expectedPort)
    }

    func start(startedAt: Date, workstreamID: UUID) {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        self.timer = timer
        timer.schedule(deadline: .now() + .seconds(1), repeating: .seconds(1))
        timer.setEventHandler { [weak self] in
            guard let self, self.active else { return }
            self.pollCount += 1

            let ports = listeningPorts(in: processTree(rootPID: self.pid))
            let result = self.tracker.update(listeningPorts: ports)
            self.detectedPorts = result.detectedPorts
            self.selectedPort = result.selectedPort

            let status: RunStateStatus = result.detectedPorts.isEmpty ? .starting : .running
            let state = RunStateSnapshot(
                pid: self.pid,
                status: status,
                detectedPorts: result.detectedPorts,
                selectedPort: result.selectedPort,
                startedAt: startedAt
            )
            try? RunStateStore.write(state, for: workstreamID)

            if result.selectedPort != nil {
                self.active = false
                timer.cancel()
                return
            }

            if self.pollCount == 60 {
                timer.schedule(deadline: .now() + .seconds(60), repeating: .seconds(60))
            }
        }
        self.active = true
        timer.resume()
    }

    func stop() {
        queue.sync {
            active = false
            timer?.cancel()
            timer = nil
        }
    }

    private func processTree(rootPID: Int32) -> Set<Int32> {
        var pending: [Int32] = [rootPID]
        var visited: Set<Int32> = [rootPID]

        while let currentPID = pending.popLast() {
            for childPID in childPIDs(of: currentPID) where visited.insert(childPID).inserted {
                pending.append(childPID)
            }
        }

        return visited
    }

    private func childPIDs(of pid: Int32) -> [Int32] {
        let byteCount = proc_listchildpids(pid, nil, 0)
        guard byteCount > 0 else { return [] }

        let count = Int(byteCount) / MemoryLayout<Int32>.stride
        var children = [Int32](repeating: 0, count: count)
        let filledBytes = children.withUnsafeMutableBytes { buffer in
            proc_listchildpids(pid, buffer.baseAddress, Int32(buffer.count))
        }
        guard filledBytes > 0 else { return [] }
        return Array(children.prefix(Int(filledBytes) / MemoryLayout<Int32>.stride))
    }

    private func listeningPorts(in pids: Set<Int32>) -> Set<Int> {
        var ports: Set<Int> = []

        for pid in pids {
            for fd in socketFDs(for: pid) {
                var socketInfo = socket_fdinfo()
                let filled = withUnsafeMutablePointer(to: &socketInfo) { pointer in
                    pointer.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<socket_fdinfo>.size) { buffer in
                        proc_pidfdinfo(pid, fd.proc_fd, PROC_PIDFDSOCKETINFO, buffer, Int32(MemoryLayout<socket_fdinfo>.size))
                    }
                }

                guard filled == Int32(MemoryLayout<socket_fdinfo>.size) else { continue }
                guard socketInfo.psi.soi_family == AF_INET || socketInfo.psi.soi_family == AF_INET6 else { continue }
                guard socketInfo.psi.soi_kind == SOCKINFO_TCP else { continue }
                guard socketInfo.psi.soi_proto.pri_tcp.tcpsi_state == TSI_S_LISTEN else { continue }

                let rawPort = UInt16(truncatingIfNeeded: socketInfo.psi.soi_proto.pri_tcp.tcpsi_ini.insi_lport)
                let port = Int(rawPort.byteSwapped)
                if port > 0 {
                    ports.insert(port)
                }
            }
        }

        return ports
    }

    private func socketFDs(for pid: Int32) -> [proc_fdinfo] {
        let byteCount = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard byteCount > 0 else { return [] }

        let count = Int(byteCount) / MemoryLayout<proc_fdinfo>.stride
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: count)
        let filledBytes = fds.withUnsafeMutableBytes { buffer in
            proc_pidinfo(pid, PROC_PIDLISTFDS, 0, buffer.baseAddress, Int32(buffer.count))
        }
        guard filledBytes > 0 else { return [] }

        return Array(fds.prefix(Int(filledBytes) / MemoryLayout<proc_fdinfo>.stride)).filter {
            $0.proc_fdtype == UInt32(PROX_FDTYPE_SOCKET)
        }
    }
}

private struct Configuration {
    let workstreamID: UUID
    let command: [String]
    let expectedPort: Int?
    let startedAt: Date

    init(arguments: [String]) throws {
        var workstreamID: UUID?
        var commandStartIndex: Int?
        var index = 1

        while index < arguments.count {
            let argument = arguments[index]
            if argument == "--" {
                commandStartIndex = index + 1
                break
            }
            if argument == "--workstream-id" {
                let valueIndex = index + 1
                guard valueIndex < arguments.count,
                      let parsedID = UUID(uuidString: arguments[valueIndex]) else {
                    throw LauncherError(exitCode: 2, message: "ff-run requires a valid --workstream-id")
                }
                workstreamID = parsedID
                index += 2
                continue
            }
            throw LauncherError(exitCode: 2, message: "Unknown option: \(argument)")
        }

        guard let workstreamID else {
            throw LauncherError(exitCode: 2, message: "ff-run requires --workstream-id <uuid>")
        }
        guard let commandStartIndex, commandStartIndex < arguments.count else {
            throw LauncherError(exitCode: 2, message: "ff-run requires a command after --")
        }

        self.workstreamID = workstreamID
        self.command = Array(arguments[commandStartIndex...])
        self.expectedPort = ProcessInfo.processInfo.environment["FF_PORT"].flatMap(Int.init)
        self.startedAt = Date()
    }
}

private struct LauncherError: Error {
    let exitCode: Int32
    let message: String
}
