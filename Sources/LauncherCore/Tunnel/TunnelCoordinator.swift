import Foundation

public struct TunnelSignalMessage: Equatable, Sendable {
    public let id: Int
    public let from: String
    public let payload: String

    public init(id: Int, from: String, payload: String) {
        self.id = id
        self.from = from
        self.payload = payload
    }
}

public protocol TunnelSignaling: Sendable {
    func post(to user: String, payload: String) async throws
    func fetch(after: Int) async throws -> [TunnelSignalMessage]
}

public typealias TunnelEndpointDiscovery = @Sendable (UDPSocket) -> TunnelEndpoint?

private struct TunnelHandshake: Codable {
    let kind: String
    let session: String
    let endpoint: String
}

private func encodeHandshake(_ handshake: TunnelHandshake) -> String? {
    guard let data = try? JSONEncoder().encode(handshake) else { return nil }
    return String(data: data, encoding: .utf8)
}

private func decodeHandshake(_ payload: String) -> TunnelHandshake? {
    guard let data = payload.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(TunnelHandshake.self, from: data)
}

private func sleepFor(_ interval: TimeInterval) async {
    guard interval > 0 else {
        await Task.yield()
        return
    }

    let maximum = Double(UInt64.max) / 1_000_000_000
    let nanoseconds = UInt64(min(interval, maximum) * 1_000_000_000)
    try? await Task.sleep(nanoseconds: nanoseconds)
}

public final class TunnelHostService: @unchecked Sendable {
    private let signaling: TunnelSignaling
    private let tunnelKeyHex: String
    private let serverPort: UInt16
    private let bindAddress: String
    private let discover: TunnelEndpointDiscovery
    private let pollInterval: TimeInterval
    private let punchTimeout: TimeInterval

    private let lock = NSLock()
    private var stopped = false
    private var pollingTask: Task<Void, Never>?
    private var seenSessions = Set<String>()
    private var links: [TunnelLink] = []

    public init(
        signaling: TunnelSignaling,
        tunnelKeyHex: String,
        serverPort: UInt16,
        bindAddress: String = "0.0.0.0",
        discover: @escaping TunnelEndpointDiscovery = { STUNClient.discover(using: $0) },
        pollInterval: TimeInterval = 1.0,
        punchTimeout: TimeInterval = 20
    ) {
        self.signaling = signaling
        self.tunnelKeyHex = tunnelKeyHex
        self.serverPort = serverPort
        self.bindAddress = bindAddress
        self.discover = discover
        self.pollInterval = pollInterval
        self.punchTimeout = punchTimeout
    }

    public func start() {
        lock.lock()
        guard !stopped, pollingTask == nil else {
            lock.unlock()
            return
        }

        pollingTask = Task { [weak self] in
            await self?.poll()
        }
        lock.unlock()
    }

    public func stop() {
        lock.lock()
        guard !stopped else {
            lock.unlock()
            return
        }

        stopped = true
        let task = pollingTask
        pollingTask = nil
        let currentLinks = links
        links.removeAll()
        lock.unlock()

        task?.cancel()
        for link in currentLinks {
            link.close()
        }
    }

    public var activeLinkCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return links.count
    }

    private func poll() async {
        var lastID = 0

        while !Task.isCancelled {
            do {
                let messages = try await signaling.fetch(after: lastID)
                for message in messages {
                    lastID = max(lastID, message.id)

                    guard let handshake = decodeHandshake(message.payload),
                          handshake.kind == "hello",
                          !handshake.session.isEmpty,
                          let endpoint = TunnelEndpoint(handshake.endpoint),
                          markSessionSeen(handshake.session)
                    else {
                        continue
                    }

                    Task.detached(priority: nil) { [weak self] in
                        await self?.handleHello(
                            message: message,
                            session: handshake.session,
                            endpoint: endpoint
                        )
                    }
                }
            } catch {
                // Polling continues when the signaling service is unavailable.
            }

            await sleepFor(pollInterval)
        }
    }

    private func markSessionSeen(_ session: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !stopped, !seenSessions.contains(session) else { return false }
        seenSessions.insert(session)
        return true
    }

    private func isStopped() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return stopped
    }

    private func handleHello(
        message: TunnelSignalMessage,
        session: String,
        endpoint: TunnelEndpoint
    ) async {
        guard !isStopped() else { return }

        let socket: UDPSocket
        do {
            socket = try UDPSocket(port: 0, bindAddress: bindAddress)
        } catch {
            return
        }

        guard let publicEndpoint = discover(socket) else {
            socket.close()
            return
        }

        guard !isStopped(),
              let payload = encodeHandshake(
                TunnelHandshake(
                    kind: "reply",
                    session: session,
                    endpoint: publicEndpoint.description
                )
              )
        else {
            socket.close()
            return
        }

        do {
            try await signaling.post(to: message.from, payload: payload)
        } catch {
            socket.close()
            return
        }

        guard !isStopped() else {
            socket.close()
            return
        }

        let link = TunnelLink(
            socket: socket,
            remote: endpoint,
            tunnelKeyHex: tunnelKeyHex,
            role: .host
        )

        do {
            try link.connect(timeout: punchTimeout)
        } catch {
            link.close()
            return
        }

        link.onClosed = { [weak self, weak link] in
            guard let link else { return }
            self?.remove(link)
        }

        guard keep(link) else {
            link.close()
            return
        }

        link.serve(localPort: serverPort)
    }

    private func keep(_ link: TunnelLink) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !stopped else { return false }
        links.append(link)
        return true
    }

    private func remove(_ link: TunnelLink) {
        lock.lock()
        links.removeAll { $0 === link }
        lock.unlock()
    }

    deinit {
        stop()
    }
}

public final class TunnelGuestService: @unchecked Sendable {
    private let signaling: TunnelSignaling
    private let hostUser: String
    private let tunnelKeyHex: String
    private let bindAddress: String
    private let discover: TunnelEndpointDiscovery
    private let pollInterval: TimeInterval
    private let timeout: TimeInterval

    private let lock = NSLock()
    private var stopped = false
    private var link: TunnelLink?
    private var closedHandler: (@Sendable () -> Void)?

    public init(
        signaling: TunnelSignaling,
        hostUser: String,
        tunnelKeyHex: String,
        bindAddress: String = "0.0.0.0",
        discover: @escaping TunnelEndpointDiscovery = { STUNClient.discover(using: $0) },
        pollInterval: TimeInterval = 0.5,
        timeout: TimeInterval = 25
    ) {
        self.signaling = signaling
        self.hostUser = hostUser
        self.tunnelKeyHex = tunnelKeyHex
        self.bindAddress = bindAddress
        self.discover = discover
        self.pollInterval = pollInterval
        self.timeout = timeout
    }

    public var onClosed: (@Sendable () -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return closedHandler
        }
        set {
            lock.lock()
            closedHandler = newValue
            lock.unlock()
        }
    }

    public func connect() async throws -> UInt16 {
        guard canConnect() else { throw TunnelError.closed }

        let socket = try UDPSocket(port: 0, bindAddress: bindAddress)
        var handedOff = false
        defer {
            if !handedOff {
                socket.close()
            }
        }

        let publicEndpoint = await Task.detached(priority: nil) { [discover] in
            discover(socket)
        }.value

        guard let publicEndpoint else {
            throw TunnelError.noPublicEndpoint
        }

        let session = UUID().uuidString
        guard let hello = encodeHandshake(
            TunnelHandshake(
                kind: "hello",
                session: session,
                endpoint: publicEndpoint.description
            )
        ) else {
            throw TunnelError.handshakeFailed
        }

        try await signaling.post(to: hostUser, payload: hello)

        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        var lastID = 0
        var remoteEndpoint: TunnelEndpoint?

        while remoteEndpoint == nil {
            guard !Task.isCancelled else { throw TunnelError.closed }
            guard ProcessInfo.processInfo.systemUptime < deadline else {
                throw TunnelError.timeout
            }

            do {
                let messages = try await signaling.fetch(after: lastID)
                for message in messages {
                    lastID = max(lastID, message.id)

                    guard message.from == hostUser,
                          let handshake = decodeHandshake(message.payload),
                          handshake.kind == "reply",
                          handshake.session == session,
                          let endpoint = TunnelEndpoint(handshake.endpoint)
                    else {
                        continue
                    }

                    remoteEndpoint = endpoint
                    break
                }
            } catch {
                // Keep polling until the overall connection timeout expires.
            }

            if remoteEndpoint == nil {
                let remaining = deadline - ProcessInfo.processInfo.systemUptime
                if remaining > 0 {
                    await sleepFor(min(pollInterval, remaining))
                }
            }
        }

        guard let remoteEndpoint else {
            throw TunnelError.timeout
        }

        let link = TunnelLink(
            socket: socket,
            remote: remoteEndpoint,
            tunnelKeyHex: tunnelKeyHex,
            role: .guest
        )

        link.onClosed = { [weak self, weak link] in
            guard let link else { return }
            self?.linkDidClose(link)
        }

        guard install(link) else {
            link.close()
            throw TunnelError.closed
        }
        handedOff = true

        do {
            try await Task.detached(priority: nil) { [timeout] in
                try link.connect(timeout: timeout)
            }.value
        } catch {
            link.close()
            throw error
        }

        do {
            return try link.listen()
        } catch {
            link.close()
            throw error
        }
    }

    public func stop() {
        lock.lock()
        stopped = true
        let currentLink = link
        link = nil
        lock.unlock()

        currentLink?.close()
    }

    private func canConnect() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !stopped && link == nil
    }

    private func install(_ newLink: TunnelLink) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !stopped, link == nil else { return false }
        link = newLink
        return true
    }

    private func linkDidClose(_ closedLink: TunnelLink) {
        lock.lock()
        if link === closedLink {
            link = nil
        }
        let handler = closedHandler
        lock.unlock()

        handler?()
    }

    deinit {
        stop()
    }
}
