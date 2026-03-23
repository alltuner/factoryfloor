// ABOUTME: Spawns a port monitor, then execs the user's command to preserve PTY inheritance.
// ABOUTME: The monitor scans for listening TCP ports and writes run-state files.

import Darwin
import Foundation

do {
    let configuration = try Configuration(arguments: CommandLine.arguments)
    if configuration.monitorMode {
        runMonitor(configuration: configuration)
    } else {
        try launchCommand(configuration: configuration)
    }
} catch let error as LauncherError {
    FileHandle.standardError.write(Data((error.message + "\n").utf8))
    exit(error.exitCode)
} catch {
    FileHandle.standardError.write(Data("ff-run failed: \(error.localizedDescription)\n".utf8))
    exit(1)
}

// MARK: - Launcher (parent mode)

/// Spawn a background monitor process, then exec the user's command.
/// exec preserves the PID and PTY file descriptors, so terminal
/// emulators like ghostty render output correctly.
private func launchCommand(configuration: Configuration) throws {
    let commandPID = getpid()

    // Spawn a copy of ourselves in monitor mode.
    var pathBuf = [CChar](repeating: 0, count: Int(MAXPATHLEN))
    var pathLen = UInt32(pathBuf.count)
    guard _NSGetExecutablePath(&pathBuf, &pathLen) == 0 else {
        throw LauncherError(exitCode: 1, message: "cannot determine ff-run path")
    }
    let selfPath = String(cString: pathBuf)

    let monitorArgs = [
        selfPath,
        "--monitor",
        "--pid", "\(commandPID)",
        "--workstream-id", configuration.workstreamID.uuidString.lowercased(),
    ]
    var monitorPID: pid_t = 0
    let argv = monitorArgs.map { strdup($0) } + [nil]
    defer { argv.forEach { free($0) } }

    var attrs: posix_spawnattr_t?
    posix_spawnattr_init(&attrs)
    defer { posix_spawnattr_destroy(&attrs) }

    let spawnResult = posix_spawn(&monitorPID, selfPath, nil, &attrs, argv, environ)
    guard spawnResult == 0 else {
        throw LauncherError(exitCode: 1, message: "failed to spawn monitor: \(String(cString: strerror(spawnResult)))")
    }

    // exec the user's command, replacing this process.
    let cmdArgv = configuration.command.map { strdup($0) } + [nil]
    execvp(configuration.command[0], cmdArgv)

    // exec only returns on failure
    let err = String(cString: strerror(errno))
    FileHandle.standardError.write(Data("ff-run: exec failed: \(err)\n".utf8))
    kill(monitorPID, SIGTERM)
    exit(1)
}

// MARK: - Monitor (child mode)

/// Run as a background port monitor. Scans ports in the process tree of the
/// given PID and writes state files until the process exits.
private func runMonitor(configuration: Configuration) -> Never {
    guard let commandPID = configuration.monitorPID else {
        exit(1)
    }

    // Detach from the terminal so signals go to the foreground command.
    signal(SIGINT, SIG_IGN)
    signal(SIGTERM, SIG_IGN)
    signal(SIGHUP, SIG_IGN)

    writeState(
        configuration: configuration,
        pid: commandPID,
        status: .starting,
        detectedPorts: [],
        selectedPort: nil
    )

    let scanner = PortScanner(pid: commandPID, expectedPort: configuration.expectedPort)
    scanner.start(startedAt: configuration.startedAt, workstreamID: configuration.workstreamID)

    // Poll until the command process exits.
    while kill(commandPID, 0) == 0 {
        Thread.sleep(forTimeInterval: 0.5)
    }

    scanner.stop()

    writeState(
        configuration: configuration,
        pid: commandPID,
        status: .stopped,
        detectedPorts: scanner.detectedPorts,
        selectedPort: scanner.selectedPort
    )
    RunStateStore.remove(for: configuration.workstreamID)
    exit(0)
}

private func writeState(configuration: Configuration, pid: Int32, status: RunStateStatus, detectedPorts: [Int], selectedPort: Int?) {
    let state = RunStateSnapshot(
        pid: pid,
        status: status,
        detectedPorts: detectedPorts.sorted(),
        selectedPort: selectedPort,
        startedAt: configuration.startedAt
    )
    try? RunStateStore.write(state, for: configuration.workstreamID)
}

// MARK: - Port Scanner

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
        tracker = PortSelectionTracker(expectedPort: expectedPort)
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
        active = true
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
        // proc_listchildpids returns the number of PIDs (not bytes)
        let estimatedCount = proc_listchildpids(pid, nil, 0)
        guard estimatedCount > 0 else { return [] }

        var children = [Int32](repeating: 0, count: Int(estimatedCount))
        let filledCount = children.withUnsafeMutableBufferPointer { buffer in
            proc_listchildpids(pid, buffer.baseAddress, Int32(buffer.count * MemoryLayout<Int32>.stride))
        }
        guard filledCount > 0 else { return [] }
        return Array(children.prefix(Int(filledCount)))
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

// MARK: - Configuration

private struct Configuration {
    let workstreamID: UUID
    let command: [String]
    let expectedPort: Int?
    let startedAt: Date
    let monitorMode: Bool
    let monitorPID: Int32?

    init(arguments: [String]) throws {
        var workstreamID: UUID?
        var commandStartIndex: Int?
        var monitorMode = false
        var monitorPID: Int32?
        var index = 1

        while index < arguments.count {
            let argument = arguments[index]
            if argument == "--" {
                commandStartIndex = index + 1
                break
            }
            if argument == "--monitor" {
                monitorMode = true
                index += 1
                continue
            }
            if argument == "--pid" {
                let valueIndex = index + 1
                guard valueIndex < arguments.count,
                      let pid = Int32(arguments[valueIndex])
                else {
                    throw LauncherError(exitCode: 2, message: "ff-run --pid requires a valid PID")
                }
                monitorPID = pid
                index += 2
                continue
            }
            if argument == "--workstream-id" {
                let valueIndex = index + 1
                guard valueIndex < arguments.count,
                      let parsedID = UUID(uuidString: arguments[valueIndex])
                else {
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

        self.monitorMode = monitorMode
        self.monitorPID = monitorPID
        self.workstreamID = workstreamID
        expectedPort = ProcessInfo.processInfo.environment["FF_PORT"].flatMap(Int.init)
        startedAt = Date()

        if monitorMode {
            command = []
        } else {
            guard let commandStartIndex, commandStartIndex < arguments.count else {
                throw LauncherError(exitCode: 2, message: "ff-run requires a command after --")
            }
            command = Array(arguments[commandStartIndex...])
        }
    }
}

private struct LauncherError: Error {
    let exitCode: Int32
    let message: String
}
