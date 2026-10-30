import Foundation
import Testing
@testable import LauncherCore

private struct TunnelLinkTestFailure: Error {}

private final class ConnectResult: @unchecked Sendable {
    private let lock = NSLock()
    private var didFail = false

    func fail() {
        lock.lock()
        didFail = true
        lock.unlock()
    }

    var failed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didFail
    }
}

private final class EchoServer: @unchecked Sendable {
    private let listener: TCPSocket
    private let lock = NSLock()
    private var clients: [ObjectIdentifier: TCPSocket] = [:]
    private var stopped = false

    init() throws {
        listener = try TCPSocket.listen(port: 0, loopbackOnly: true)
        let thread = Thread { [weak self] in
            self?.acceptLoop()
        }
        thread.start()
    }

    var port: UInt16 {
        listener.localPort
    }

    var openConnectionCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return clients.count
    }

    func stop() {
        lock.lock()
        guard !stopped else {
            lock.unlock()
            return
        }
        stopped = true
        let currentClients = Array(clients.values)
        clients.removeAll()
        lock.unlock()

        listener.close()
        for client in currentClients {
            client.close()
        }
    }

    private func acceptLoop() {
        while true {
            guard let client = listener.accept(timeout: 0.1) else {
                lock.lock()
                let shouldStop = stopped
                lock.unlock()
                if shouldStop {
                    return
                }
                continue
            }

            lock.lock()
            if stopped {
                lock.unlock()
                client.close()
                return
            }
            clients[ObjectIdentifier(client)] = client
            lock.unlock()

            let thread = Thread { [weak self] in
                self?.echo(client)
            }
            thread.start()
        }
    }

    private func echo(_ client: TCPSocket) {
        defer {
            client.close()
            lock.lock()
            clients.removeValue(forKey: ObjectIdentifier(client))
            lock.unlock()
        }

        while true {
            switch client.read(maxBytes: 8192, timeout: 0.2) {
            case .data(let bytes):
                guard client.writeAll(bytes) else { return }
            case .timeout:
                continue
            case .closed:
                return
            }
        }
    }

    deinit {
        stop()
    }
}

private func pseudoRandomData(count: Int, seed: UInt32) -> Data {
    var value = seed
    var result = Data(capacity: count)

    for _ in 0..<count {
        value = value &* 1_664_525 &+ 1_013_904_223
        result.append(UInt8(truncatingIfNeeded: value >> 24))
    }

    return result
}

private func readEcho(
    from socket: TCPSocket,
    bytes: Data,
    timeout: TimeInterval
) -> Data {
    guard socket.writeAll(bytes) else { return Data() }

    let deadline = ProcessInfo.processInfo.systemUptime + timeout
    var result = Data(capacity: bytes.count)

    while result.count < bytes.count,
          ProcessInfo.processInfo.systemUptime < deadline {
        switch socket.read(maxBytes: 8192, timeout: 0.2) {
        case .data(let received):
            result.append(received)
        case .timeout:
            continue
        case .closed:
            return result
        }
    }

    return result
}

private func makeConnectedLinks() throws -> (TunnelLink, TunnelLink) {
    let hostSocket = try UDPSocket(port: 0, bindAddress: "127.0.0.1")
    let guestSocket = try UDPSocket(port: 0, bindAddress: "127.0.0.1")

    let host = TunnelLink(
        socket: hostSocket,
        remote: TunnelEndpoint(host: "127.0.0.1", port: guestSocket.localPort),
        tunnelKeyHex: "loopback-tunnel-key",
        role: .host
    )
    let guest = TunnelLink(
        socket: guestSocket,
        remote: TunnelEndpoint(host: "127.0.0.1", port: hostSocket.localPort),
        tunnelKeyHex: "loopback-tunnel-key",
        role: .guest
    )

    let hostResult = ConnectResult()
    let guestResult = ConnectResult()
    let hostDone = DispatchSemaphore(value: 0)
    let guestDone = DispatchSemaphore(value: 0)

    Thread {
        do {
            try host.connect()
        } catch {
            hostResult.fail()
        }
        hostDone.signal()
    }.start()

    Thread {
        do {
            try guest.connect()
        } catch {
            guestResult.fail()
        }
        guestDone.signal()
    }.start()

    guard hostDone.wait(timeout: .now() + .seconds(5)) == .success,
          guestDone.wait(timeout: .now() + .seconds(5)) == .success,
          !hostResult.failed,
          !guestResult.failed
    else {
        host.close()
        guest.close()
        throw TunnelLinkTestFailure()
    }

    return (host, guest)
}

@Test
func largePayloadRoundTripsThroughTunnel() throws {
    let echo = try EchoServer()
    let (host, guest) = try makeConnectedLinks()
    defer {
        host.close()
        guest.close()
        echo.stop()
    }

    host.serve(localPort: echo.port)
    let guestPort = try guest.listen()
    let client = try TCPSocket.connect(host: "127.0.0.1", port: guestPort)
    defer { client.close() }

    let sent = pseudoRandomData(count: 300_000, seed: 17)
    let received = readEcho(from: client, bytes: sent, timeout: 20)

    #expect(received.count == sent.count)
    #expect(received == sent)
}

@Test
func threeConnectionsRoundTripSimultaneously() throws {
    let echo = try EchoServer()
    let (host, guest) = try makeConnectedLinks()
    defer {
        host.close()
        guest.close()
        echo.stop()
    }

    host.serve(localPort: echo.port)
    let guestPort = try guest.listen()

    let sockets = try (0..<3).map { _ in
        try TCPSocket.connect(host: "127.0.0.1", port: guestPort)
    }
    defer {
        for socket in sockets {
            socket.close()
        }
    }

    let payloads = (0..<3).map {
        pseudoRandomData(count: 50_000, seed: UInt32(100 + $0))
    }
    let resultsLock = NSLock()
    var results = [Data?](repeating: nil, count: sockets.count)
    let done = DispatchSemaphore(value: 0)

    for index in sockets.indices {
        Thread {
            let result = readEcho(
                from: sockets[index],
                bytes: payloads[index],
                timeout: 20
            )
            resultsLock.lock()
            results[index] = result
            resultsLock.unlock()
            done.signal()
        }.start()
    }

    for _ in sockets.indices {
        #expect(done.wait(timeout: .now() + .seconds(20)) == .success)
    }

    for index in sockets.indices {
        resultsLock.lock()
        let result = results[index]
        resultsLock.unlock()
        #expect(result == payloads[index])
    }
}

@Test
func wrongKeyFailsHandshake() throws {
    let hostSocket = try UDPSocket(port: 0, bindAddress: "127.0.0.1")
    let guestSocket = try UDPSocket(port: 0, bindAddress: "127.0.0.1")

    let host = TunnelLink(
        socket: hostSocket,
        remote: TunnelEndpoint(host: "127.0.0.1", port: guestSocket.localPort),
        tunnelKeyHex: "correct-key",
        role: .host
    )
    let guest = TunnelLink(
        socket: guestSocket,
        remote: TunnelEndpoint(host: "127.0.0.1", port: hostSocket.localPort),
        tunnelKeyHex: "wrong-key",
        role: .guest
    )
    defer {
        host.close()
        guest.close()
    }

    var failed = false
    do {
        try guest.connect(timeout: 1)
    } catch TunnelError.handshakeFailed {
        failed = true
    } catch {
        failed = false
    }

    #expect(failed)
}

@Test
func closingGuestNotifiesHost() throws {
    let (host, guest) = try makeConnectedLinks()
    defer {
        host.close()
        guest.close()
    }

    let closed = DispatchSemaphore(value: 0)
    host.onClosed = {
        closed.signal()
    }

    guest.close()

    #expect(closed.wait(timeout: .now() + .seconds(5)) == .success)
}

@Test
func clientCloseReachesEchoServer() throws {
    let echo = try EchoServer()
    let (host, guest) = try makeConnectedLinks()
    defer {
        host.close()
        guest.close()
        echo.stop()
    }

    host.serve(localPort: echo.port)
    let guestPort = try guest.listen()
    let client = try TCPSocket.connect(host: "127.0.0.1", port: guestPort)

    let payload = pseudoRandomData(count: 2_048, seed: 901)
    let received = readEcho(from: client, bytes: payload, timeout: 10)
    #expect(received == payload)

    let connectedDeadline = ProcessInfo.processInfo.systemUptime + 5
    while echo.openConnectionCount == 0,
          ProcessInfo.processInfo.systemUptime < connectedDeadline {
        Thread.sleep(forTimeInterval: 0.01)
    }
    #expect(echo.openConnectionCount > 0)

    client.close()

    let closedDeadline = ProcessInfo.processInfo.systemUptime + 5
    while echo.openConnectionCount != 0,
          ProcessInfo.processInfo.systemUptime < closedDeadline {
        Thread.sleep(forTimeInterval: 0.01)
    }

    #expect(echo.openConnectionCount == 0)
}
