import Foundation

/// Joins one host launcher and one guest launcher over a reliable UDP tunnel.
public final class TunnelLink: @unchecked Sendable {
    public enum Role: Sendable {
        case host
        case guest
    }

    private final class Channel: @unchecked Sendable {
        let id: UInt32
        let socket: TCPSocket

        init(id: UInt32, socket: TCPSocket) {
            self.id = id
            self.socket = socket
        }
    }

    private let socket: UDPSocket
    private let cipher: TunnelCipher
    private let role: Role
    private let initialRemote: TunnelEndpoint

    private let stateLock = NSLock()
    private let sendLock = NSLock()

    private var onClosedStorage: (@Sendable () -> Void)?
    private var latchedRemote: TunnelEndpoint?
    private var stream: ReliableStream?
    private var decoder = TunnelFrameCodec.Decoder()
    private var channels: [UInt32: Channel] = [:]
    private var nextChannelID: UInt32 = 1
    private var hostLocalPort: UInt16?
    private var listeningSocket: TCPSocket?
    private var stopped = false
    private var closeRequested = false
    private var connecting = false
    private var callbackDelivered = false

    public var onClosed: (@Sendable () -> Void)? {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return onClosedStorage
        }
        set {
            stateLock.lock()
            onClosedStorage = newValue
            stateLock.unlock()
        }
    }

    public init(
        socket: UDPSocket,
        remote: TunnelEndpoint,
        tunnelKeyHex: String,
        role: Role
    ) {
        self.socket = socket
        self.initialRemote = remote
        self.role = role

        switch role {
        case .host:
            self.cipher = TunnelCipher(tunnelKeyHex: tunnelKeyHex, isHost: true)
        case .guest:
            self.cipher = TunnelCipher(tunnelKeyHex: tunnelKeyHex, isHost: false)
        }
    }

    public func connect(timeout: TimeInterval = 15) throws {
        stateLock.lock()
        if stopped {
            stateLock.unlock()
            throw TunnelError.closed
        }
        if stream != nil || connecting {
            stateLock.unlock()
            return
        }
        connecting = true
        stateLock.unlock()

        let started = Self.now
        var nextPunch = started
        let deadline = started + max(0, timeout)

        while Self.now < deadline {
            let current = Self.now
            if current >= nextPunch {
                socket.send(cipher.seal(Data([0])), to: initialRemote)
                nextPunch += 0.15
            }

            let remaining = max(0, deadline - Self.now)
            if let (datagram, source) = socket.receive(timeout: min(0.02, remaining)),
               cipher.open(datagram) != nil {
                stateLock.lock()
                let canConnect = !stopped && !closeRequested
                if canConnect {
                    latchedRemote = source
                    stream = ReliableStream(start: Self.now)
                    connecting = false
                } else {
                    connecting = false
                }
                let connectedStream = stream
                stateLock.unlock()

                guard canConnect, connectedStream != nil else {
                    throw TunnelError.closed
                }

                socket.send(cipher.seal(Data([0])), to: source)
                socket.send(cipher.seal(Data([0])), to: source)
                startPump()
                return
            }

            stateLock.lock()
            let shouldStop = stopped || closeRequested
            stateLock.unlock()
            if shouldStop {
                stateLock.lock()
                connecting = false
                stateLock.unlock()
                throw TunnelError.closed
            }
        }

        stateLock.lock()
        connecting = false
        let wasStopped = stopped || closeRequested
        stateLock.unlock()
        if wasStopped {
            throw TunnelError.closed
        }
        throw TunnelError.handshakeFailed
    }

    public func serve(localPort: UInt16) {
        stateLock.lock()
        hostLocalPort = localPort
        stateLock.unlock()
    }

    public func listen(port: UInt16 = 0) throws -> UInt16 {
        let listener = try TCPSocket.listen(port: port, loopbackOnly: true)

        stateLock.lock()
        guard !stopped, !closeRequested else {
            stateLock.unlock()
            listener.close()
            throw TunnelError.closed
        }
        listeningSocket = listener
        let selectedPort = listener.localPort
        stateLock.unlock()

        let thread = Thread { [weak self] in
            self?.acceptLoop(listener)
        }
        thread.start()
        return selectedPort
    }

    public func close() {
        stateLock.lock()
        if stopped {
            stateLock.unlock()
            return
        }
        let currentStream = stream
        let listener = listeningSocket
        stateLock.unlock()

        // Queue the close packet before the pump may see closeRequested, or it stops without sending it.
        currentStream?.close()
        stateLock.lock()
        closeRequested = true
        stateLock.unlock()
        listener?.close()

        let deadline = Self.now + 0.3
        while Self.now < deadline {
            stateLock.lock()
            let finished = stopped
            stateLock.unlock()
            if finished {
                return
            }
            Thread.sleep(forTimeInterval: 0.005)
        }

        finish()
    }

    private static var now: TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    private func startPump() {
        let thread = Thread { [weak self] in
            self?.pump()
        }
        thread.start()
    }

    private func pump() {
        guard let currentStream = streamSnapshot(),
              let endpoint = remoteSnapshot()
        else {
            finish()
            return
        }

        while true {
            if let (datagram, source) = socket.receive(timeout: 0.01),
               source == endpoint,
               let plaintext = cipher.open(datagram),
               plaintext.first != 0 {
                currentStream.receive(packet: plaintext, now: Self.now)
            }

            let readable = currentStream.readAvailable()
            if !readable.isEmpty {
                let frames = decoder.feed(readable)
                if decoder.isCorrupt {
                    finish()
                    return
                }
                for frame in frames {
                    handleFrame(frame)
                }
            }

            let now = Self.now
            for packet in currentStream.pendingPackets(now: now) {
                socket.send(cipher.seal(packet), to: endpoint)
            }

            stateLock.lock()
            let shouldFinish = stopped || closeRequested
            stateLock.unlock()

            if shouldFinish ||
                currentStream.peerClosed ||
                currentStream.isIdleTooLong(now: now) {
                finish()
                return
            }
        }
    }

    private func handleFrame(_ frame: TunnelFrame) {
        switch frame.kind {
        case .open:
            handleOpen(frame.channel)
        case .data:
            guard let channel = channel(for: frame.channel) else {
                sendFrame(TunnelFrame(kind: .close, channel: frame.channel, payload: Data()))
                return
            }
            if !channel.socket.writeAll(frame.payload) {
                closeChannel(channel, notifyPeer: true)
            }
        case .close:
            if let channel = channel(for: frame.channel) {
                closeChannel(channel, notifyPeer: false)
            }
        }
    }

    private func handleOpen(_ id: UInt32) {
        guard roleIsHost else {
            sendFrame(TunnelFrame(kind: .close, channel: id, payload: Data()))
            return
        }

        stateLock.lock()
        let port = hostLocalPort
        stateLock.unlock()

        guard let port else {
            sendFrame(TunnelFrame(kind: .close, channel: id, payload: Data()))
            return
        }

        if let existing = channel(for: id) {
            closeChannel(existing, notifyPeer: true)
        }

        do {
            let channelSocket = try TCPSocket.connect(
                host: "127.0.0.1",
                port: port
            )
            attach(socket: channelSocket, id: id)
        } catch {
            sendFrame(TunnelFrame(kind: .close, channel: id, payload: Data()))
        }
    }

    private func acceptLoop(_ listener: TCPSocket) {
        while !shouldStop {
            guard let channelSocket = listener.accept(timeout: 0.2) else {
                continue
            }

            stateLock.lock()
            let id = nextChannelID
            nextChannelID &+= 1
            let canAttach = !stopped && !closeRequested
            stateLock.unlock()

            guard canAttach else {
                channelSocket.close()
                return
            }

            // Only the guest's accept side originates .open; the host just
            // attaches the local TCP socket it made in response.
            sendFrame(TunnelFrame(kind: .open, channel: id, payload: Data()))
            attach(socket: channelSocket, id: id)
        }
    }

    private func attach(socket: TCPSocket, id: UInt32) {
        let channel = Channel(id: id, socket: socket)

        stateLock.lock()
        let canAttach = !stopped && !closeRequested && stream != nil
        if canAttach {
            channels[id] = channel
        }
        stateLock.unlock()

        guard canAttach else {
            socket.close()
            return
        }

        let thread = Thread { [weak self] in
            self?.readChannel(channel)
        }
        thread.start()
    }

    private func readChannel(_ channel: Channel) {
        while isCurrent(channel) && !shouldStop {
            guard let currentStream = streamSnapshot() else {
                break
            }

            while currentStream.queuedBytes > 1_000_000 &&
                isCurrent(channel) &&
                !shouldStop {
                Thread.sleep(forTimeInterval: 0.005)
            }

            guard isCurrent(channel), !shouldStop else {
                break
            }

            switch channel.socket.read(maxBytes: 8192, timeout: 0.2) {
            case .data(let bytes):
                for frame in TunnelFrameCodec.chunks(for: channel.id, bytes: bytes) {
                    sendFrame(frame)
                }
            case .timeout:
                continue
            case .closed:
                closeChannel(channel, notifyPeer: true)
                return
            }
        }

        if isCurrent(channel) {
            closeChannel(channel, notifyPeer: false)
        }
    }

    private func sendFrame(_ frame: TunnelFrame) {
        sendLock.lock()
        defer { sendLock.unlock() }

        stateLock.lock()
        let currentStream = stream
        let active = !stopped && !closeRequested
        stateLock.unlock()

        guard active, let currentStream else { return }
        currentStream.send(TunnelFrameCodec.encode(frame))
    }

    private func closeChannel(_ channel: Channel, notifyPeer: Bool) {
        stateLock.lock()
        guard channels[channel.id] === channel else {
            stateLock.unlock()
            return
        }
        channels.removeValue(forKey: channel.id)
        stateLock.unlock()

        channel.socket.close()
        if notifyPeer {
            sendFrame(TunnelFrame(kind: .close, channel: channel.id, payload: Data()))
        }
    }

    private func channel(for id: UInt32) -> Channel? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return channels[id]
    }

    private func isCurrent(_ channel: Channel) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return channels[channel.id] === channel
    }

    private var roleIsHost: Bool {
        if case .host = role {
            return true
        }
        return false
    }

    private var shouldStop: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return stopped || closeRequested
    }

    private func streamSnapshot() -> ReliableStream? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return stream
    }

    private func remoteSnapshot() -> TunnelEndpoint? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return latchedRemote
    }

    private func finish() {
        stateLock.lock()
        guard !stopped else {
            stateLock.unlock()
            return
        }

        stopped = true
        closeRequested = true
        let channelSockets = channels.values.map(\.socket)
        channels.removeAll()
        let listener = listeningSocket
        let callback: (@Sendable () -> Void)?
        if callbackDelivered {
            callback = nil
        } else {
            callbackDelivered = true
            callback = onClosedStorage
        }
        stateLock.unlock()

        streamSnapshot()?.close()
        listener?.close()
        for channelSocket in channelSockets {
            channelSocket.close()
        }
        socket.close()
        callback?()
    }
}
