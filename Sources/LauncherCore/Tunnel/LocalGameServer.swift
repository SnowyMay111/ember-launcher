import Foundation

public enum LocalGameServerError: Error, LocalizedError, Sendable, Equatable {
    case noStableLoader
    case noStableInstaller
    case startTimedOut
    case exitedEarly(code: Int32)
    case notRunning

    public var errorDescription: String? {
        switch self {
        case .noStableLoader:
            return "No stable Fabric loader was found"
        case .noStableInstaller:
            return "No stable Fabric installer was found"
        case .startTimedOut:
            return "The local game server did not become ready before the timeout"
        case .exitedEarly(let code):
            return "The local game server exited early with code \(code)"
        case .notRunning:
            return "The local game server is not running"
        }
    }
}

private struct LocalFabricLoaderEntry: Decodable {
    struct Loader: Decodable {
        let version: String
        let stable: Bool?
    }

    let loader: Loader
}

private struct LocalFabricInstallerEntry: Decodable {
    let version: String
    let stable: Bool
}

private final class LocalGameServerStartWaiter: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var completed = false
    private var timeoutTask: Task<Void, Never>?

    init(continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    var isCompleted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return completed
    }

    @discardableResult
    func complete(_ result: Result<Void, Error>) -> Bool {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return false
        }

        completed = true
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()

        continuation?.resume(with: result)
        return true
    }

    func setTimeoutTask(_ task: Task<Void, Never>) {
        lock.lock()
        if completed {
            lock.unlock()
            task.cancel()
            return
        }

        timeoutTask = task
        lock.unlock()
    }

    func cancelTimeout() {
        lock.lock()
        let task = timeoutTask
        timeoutTask = nil
        lock.unlock()

        task?.cancel()
    }
}

private final class LocalGameServerLineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var bufferedData = Data()

    func appendAndExtractLines(_ data: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }

        bufferedData.append(data)
        var lines: [String] = []
        while let newline = bufferedData.firstIndex(of: 0x0A) {
            let lineData = bufferedData.prefix(upTo: newline)
            bufferedData.removeSubrange(0...newline)
            var line = String(decoding: lineData, as: UTF8.self)
            if line.last == "\r" {
                line.removeLast()
            }
            lines.append(line)
        }
        return lines
    }

    func flush() -> String? {
        lock.lock()
        defer { lock.unlock() }

        guard !bufferedData.isEmpty else {
            return nil
        }
        let line = String(decoding: bufferedData, as: UTF8.self)
        bufferedData.removeAll(keepingCapacity: true)
        return line
    }
}

public final class LocalGameServer: @unchecked Sendable {
    private let directory: URL
    private let javaExecutable: URL
    private let minecraftVersion: String
    private let downloader: Downloader
    private let lock = NSLock()

    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var logHandle: FileHandle?
    private var startWaiter: LocalGameServerStartWaiter?

    public init(
        directory: URL,
        javaExecutable: URL,
        minecraftVersion: String,
        downloader: Downloader = Downloader()
    ) {
        self.directory = directory
        self.javaExecutable = javaExecutable
        self.minecraftVersion = minecraftVersion
        self.downloader = downloader
    }

    public func prepareLauncherJar() async throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        let loaderURLString = "https://meta.fabricmc.net/v2/versions/loader/\(minecraftVersion)"
        guard let loaderURL = URL(string: loaderURLString) else {
            throw DownloaderError.downloadFailed(underlying: "Invalid URL: \(loaderURLString)")
        }

        let loaderEntries = try await downloader.fetchJSON([LocalFabricLoaderEntry].self, from: loaderURL)
        guard let loader = loaderEntries.first(where: { $0.loader.stable == true })?.loader.version else {
            throw LocalGameServerError.noStableLoader
        }

        let installerURLString = "https://meta.fabricmc.net/v2/versions/installer"
        guard let installerURL = URL(string: installerURLString) else {
            throw DownloaderError.downloadFailed(underlying: "Invalid URL: \(installerURLString)")
        }

        let installerEntries = try await downloader.fetchJSON([LocalFabricInstallerEntry].self, from: installerURL)
        guard let installer = installerEntries.first(where: { $0.stable })?.version else {
            throw LocalGameServerError.noStableInstaller
        }

        let launcherURL = directory.appendingPathComponent(
            "fabric-server-\(minecraftVersion)-\(loader).jar"
        )

        if !fileManager.fileExists(atPath: launcherURL.path) {
            let downloadURLString = "https://meta.fabricmc.net/v2/versions/loader/\(minecraftVersion)/\(loader)/\(installer)/server/jar"
            guard let downloadURL = URL(string: downloadURLString) else {
                throw DownloaderError.downloadFailed(underlying: "Invalid URL: \(downloadURLString)")
            }

            try await downloader.download(
                url: downloadURL,
                to: launcherURL,
                sha1: nil,
                size: nil
            )
        }

        return launcherURL
    }

    /// Stops a server of this folder left running by a launcher that was killed, so it releases the world lock.
    public static func stopStrayProcesses(in directory: URL) async {
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-axo", "pid=,command="]
        let pipe = Pipe()
        ps.standardOutput = pipe
        guard (try? ps.run()) != nil else { return }
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        ps.waitUntilExit()

        let marker = "-jar \(directory.path)/"
        let pids = output.split(separator: "\n").compactMap { line -> Int32? in
            let parts = line.drop { $0 == " " }.split(separator: " ", maxSplits: 1)
            guard parts.count == 2, parts[1].contains(marker), let pid = Int32(parts[0]), pid > 1 else { return nil }
            return pid
        }
        for pid in pids {
            kill(pid, SIGTERM)
            var waited = 0
            while kill(pid, 0) == 0 && waited < 100 {
                try? await Task.sleep(nanoseconds: 200_000_000)
                waited += 1
            }
            if kill(pid, 0) == 0 { kill(pid, SIGKILL) }
        }
    }

    public static func isReadyLine(_ line: String) -> Bool {
        line.contains("Done (") && line.contains("s)! For help, type \"help\"")
    }

    public static func launchArguments(launcherJar: URL, memoryMB: Int) -> [String] {
        ["-Xmx\(memoryMB)M", "-jar", launcherJar.path, "nogui"]
    }

    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return process?.isRunning == true
    }

    public func start(
        launcherJar: URL,
        memoryMB: Int = 2048,
        timeout: TimeInterval = 240,
        onLine: (@Sendable (String) -> Void)? = nil
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let waiter = LocalGameServerStartWaiter(continuation: continuation)

            do {
                try begin(
                    launcherJar: launcherJar,
                    memoryMB: memoryMB,
                    timeout: timeout,
                    onLine: onLine,
                    waiter: waiter
                )
            } catch {
                waiter.complete(.failure(error))
            }
        }
    }

    public func send(command: String) throws {
        lock.lock()
        guard let process, process.isRunning, let inputPipe else {
            lock.unlock()
            throw LocalGameServerError.notRunning
        }
        let handle = inputPipe.fileHandleForWriting
        lock.unlock()

        handle.write(Data("\(command)\n".utf8))
    }

    public func reloadWhitelist() throws {
        try send(command: "whitelist reload")
    }

    /// Kills the server process at once, for when the launcher itself is quitting.
    public func terminateNow() {
        let process = lock.withLock { self.process }
        if process?.isRunning == true { process?.terminate() }
    }

    public func stop(timeout: TimeInterval = 20) async {
        let (process, running) = lock.withLock { (self.process, self.process?.isRunning == true) }

        guard let process, running else {
            return
        }

        try? send(command: "stop")
        await waitForExit(process, timeout: timeout)

        if process.isRunning {
            process.terminate()
            await waitForExit(process, timeout: 1)
        }
    }

    private func begin(
        launcherJar: URL,
        memoryMB: Int,
        timeout: TimeInterval,
        onLine: (@Sendable (String) -> Void)?,
        waiter: LocalGameServerStartWaiter
    ) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        lock.lock()
        guard process == nil else {
            lock.unlock()
            throw LocalGameServerError.notRunning
        }
        lock.unlock()

        let logURL = directory.appendingPathComponent("launcher-server.log")
        if !fileManager.fileExists(atPath: logURL.path) {
            _ = fileManager.createFile(atPath: logURL.path, contents: nil)
        }

        guard let logHandle = FileHandle(forWritingAtPath: logURL.path) else {
            throw NSError(
                domain: "LauncherCore.LocalGameServer",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to open the local game server log"]
            )
        }
        logHandle.seekToEndOfFile()

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let process = Process()
        process.executableURL = javaExecutable
        process.arguments = Self.launchArguments(launcherJar: launcherJar, memoryMB: memoryMB)
        process.currentDirectoryURL = directory
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        process.terminationHandler = { [weak self] process in
            self?.processDidTerminate(process, waiter: waiter)
        }

        lock.lock()
        self.process = process
        self.inputPipe = inputPipe
        self.outputPipe = outputPipe
        self.logHandle = logHandle
        self.startWaiter = waiter
        lock.unlock()

        let bufferBox = LocalGameServerLineBuffer()
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self, weak waiter] handle in
            guard let self, let waiter else {
                return
            }

            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                if let line = bufferBox.flush() {
                    self.handleLine(line, onLine: onLine, waiter: waiter)
                }
                return
            }

            for line in bufferBox.appendAndExtractLines(data) {
                self.handleLine(line, onLine: onLine, waiter: waiter)
            }
        }

        do {
            try process.run()
        } catch {
            clearProcess(process)
            throw error
        }

        let nanoseconds: UInt64
        if !timeout.isFinite || timeout >= Double(UInt64.max) / 1_000_000_000 {
            nanoseconds = UInt64.max
        } else {
            nanoseconds = UInt64(max(0, timeout) * 1_000_000_000)
        }

        let timeoutTask = Task { [weak self, weak waiter] in
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }

            guard let self, let waiter else {
                return
            }

            self.handleStartTimeout(waiter)
        }
        waiter.setTimeoutTask(timeoutTask)
    }

    private func handleLine(
        _ line: String,
        onLine: (@Sendable (String) -> Void)?,
        waiter: LocalGameServerStartWaiter
    ) {
        let lineData = Data("\(line)\n".utf8)

        lock.lock()
        logHandle?.write(lineData)
        lock.unlock()

        if Self.isReadyLine(line), waiter.complete(.success(())) {
            waiter.cancelTimeout()
            lock.lock()
            if startWaiter === waiter {
                startWaiter = nil
            }
            lock.unlock()
        }

        onLine?(line)
    }

    private func handleStartTimeout(_ waiter: LocalGameServerStartWaiter) {
        guard waiter.complete(.failure(LocalGameServerError.startTimedOut)) else {
            return
        }

        waiter.cancelTimeout()

        lock.lock()
        let process = self.process
        lock.unlock()

        process?.terminate()
    }

    private func processDidTerminate(
        _ process: Process,
        waiter: LocalGameServerStartWaiter
    ) {
        clearProcess(process)
        waiter.cancelTimeout()
        waiter.complete(.failure(LocalGameServerError.exitedEarly(code: process.terminationStatus)))
    }

    private func clearProcess(_ process: Process) {
        var outputPipe: Pipe?
        var inputPipe: Pipe?
        var logHandle: FileHandle?

        lock.lock()
        guard self.process === process else {
            lock.unlock()
            return
        }

        self.process = nil
        inputPipe = self.inputPipe
        outputPipe = self.outputPipe
        logHandle = self.logHandle
        self.inputPipe = nil
        self.outputPipe = nil
        self.logHandle = nil
        self.startWaiter = nil
        lock.unlock()

        outputPipe?.fileHandleForReading.readabilityHandler = nil
        inputPipe?.fileHandleForWriting.closeFile()
        outputPipe?.fileHandleForReading.closeFile()
        logHandle?.closeFile()
    }

    private func waitForExit(_ process: Process, timeout: TimeInterval) async {
        guard timeout > 0 else {
            return
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}
