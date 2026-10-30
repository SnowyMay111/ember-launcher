import Foundation
import Testing
@testable import LauncherCore

private actor SignalStore {
    private var nextID = 0
    private var messages: [(id: Int, from: String, to: String, payload: String)] = []

    func post(from: String, to: String, payload: String) {
        nextID += 1
        messages.append((nextID, from, to, payload))
    }

    func fetch(for user: String, after: Int) -> [TunnelSignalMessage] {
        messages
            .filter { $0.to == user && $0.id > after }
            .map {
                TunnelSignalMessage(
                    id: $0.id,
                    from: $0.from,
                    payload: $0.payload
                )
            }
    }
}

private struct InMemorySignaling: TunnelSignaling {
    let user: String
    let store: SignalStore

    func post(to user: String, payload: String) async throws {
        await store.post(from: self.user, to: user, payload: payload)
    }

    func fetch(after: Int) async throws -> [TunnelSignalMessage] {
        await store.fetch(for: user, after: after)
    }
}

private final class EchoServer: @unchecked Sendable {
    private let listener: TCPSocket
    private let lock = NSLock()
    private var clients: [ObjectIdentifier: TCPSocket] = [:]
    private var stopped = false

    init() throws {
        listener = try TCPSocket.listen(port: 0, loopbackOnly: true)
        Thread { [weak self] in
            self?.acceptLoop()
        }.start()
    }

    var port: UInt16 {
        listener.localPort
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

            Thread { [weak self] in
                self?.echo(client)
            }.start()
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

private func loopbackDiscovery(_ socket: UDPSocket) -> TunnelEndpoint? {
    TunnelEndpoint(host: "127.0.0.1", port: socket.localPort)
}

private func makeSignalingPair(
    store: SignalStore
) -> (InMemorySignaling, InMemorySignaling) {
    (
        InMemorySignaling(user: "host-user", store: store),
        InMemorySignaling(user: "guest-user", store: store)
    )
}

@Test
func coordinatorRoundTripsOneHundredKilobytes() async throws {
    let echo = try EchoServer()
    let store = SignalStore()
    let (hostSignaling, guestSignaling) = makeSignalingPair(store: store)
    let host = TunnelHostService(
        signaling: hostSignaling,
        tunnelKeyHex: "loopback-tunnel-key",
        serverPort: echo.port,
        bindAddress: "127.0.0.1",
        discover: loopbackDiscovery,
        pollInterval: 0.01,
        punchTimeout: 5
    )
    let guest = TunnelGuestService(
        signaling: guestSignaling,
        hostUser: "host-user",
        tunnelKeyHex: "loopback-tunnel-key",
        bindAddress: "127.0.0.1",
        discover: loopbackDiscovery,
        pollInterval: 0.01,
        timeout: 5
    )
    defer {
        guest.stop()
        host.stop()
        echo.stop()
    }

    host.start()
    let guestPort = try await guest.connect()
    let client = try TCPSocket.connect(host: "127.0.0.1", port: guestPort)
    defer { client.close() }

    let sent = pseudoRandomData(count: 100_000, seed: 17)
    let received = readEcho(from: client, bytes: sent, timeout: 15)

    #expect(received == sent)
}

@Test
func twoGuestsRoundTripSimultaneously() async throws {
    let echo = try EchoServer()
    let store = SignalStore()
    let hostSignaling = InMemorySignaling(user: "host-user", store: store)
    let guestOneSignaling = InMemorySignaling(user: "guest-one", store: store)
    let guestTwoSignaling = InMemorySignaling(user: "guest-two", store: store)

    let host = TunnelHostService(
        signaling: hostSignaling,
        tunnelKeyHex: "loopback-tunnel-key",
        serverPort: echo.port,
        bindAddress: "127.0.0.1",
        discover: loopbackDiscovery,
        pollInterval: 0.01,
        punchTimeout: 5
    )
    let guestOne = TunnelGuestService(
        signaling: guestOneSignaling,
        hostUser: "host-user",
        tunnelKeyHex: "loopback-tunnel-key",
        bindAddress: "127.0.0.1",
        discover: loopbackDiscovery,
        pollInterval: 0.01,
        timeout: 5
    )
    let guestTwo = TunnelGuestService(
        signaling: guestTwoSignaling,
        hostUser: "host-user",
        tunnelKeyHex: "loopback-tunnel-key",
        bindAddress: "127.0.0.1",
        discover: loopbackDiscovery,
        pollInterval: 0.01,
        timeout: 5
    )
    defer {
        guestOne.stop()
        guestTwo.stop()
        host.stop()
        echo.stop()
    }

    host.start()

    async let firstPortTask = guestOne.connect()
    async let secondPortTask = guestTwo.connect()
    let firstPort = try await firstPortTask
    let secondPort = try await secondPortTask

    let deadline = ProcessInfo.processInfo.systemUptime + 5
    while host.activeLinkCount < 2,
          ProcessInfo.processInfo.systemUptime < deadline {
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    #expect(host.activeLinkCount == 2)

    let firstClient = try TCPSocket.connect(host: "127.0.0.1", port: firstPort)
    let secondClient = try TCPSocket.connect(host: "127.0.0.1", port: secondPort)
    defer {
        firstClient.close()
        secondClient.close()
    }

    let firstPayload = pseudoRandomData(count: 10_000, seed: 101)
    let secondPayload = pseudoRandomData(count: 10_000, seed: 202)

    async let firstResult = readEcho(
        from: firstClient,
        bytes: firstPayload,
        timeout: 15
    )
    async let secondResult = readEcho(
        from: secondClient,
        bytes: secondPayload,
        timeout: 15
    )

    let results = await (firstResult, secondResult)
    #expect(results.0 == firstPayload)
    #expect(results.1 == secondPayload)
}

@Test
func guestTimesOutWhenHostDoesNotAnswer() async {
    let store = SignalStore()
    let guestSignaling = InMemorySignaling(user: "guest-user", store: store)
    let guest = TunnelGuestService(
        signaling: guestSignaling,
        hostUser: "host-user",
        tunnelKeyHex: "loopback-tunnel-key",
        bindAddress: "127.0.0.1",
        discover: loopbackDiscovery,
        pollInterval: 0.02,
        timeout: 1
    )
    defer { guest.stop() }

    var didTimeout = false
    do {
        _ = try await guest.connect()
    } catch TunnelError.timeout {
        didTimeout = true
    } catch {
        didTimeout = false
    }

    #expect(didTimeout)
}

@Test
func guestFailsWhenDiscoveryReturnsNil() async {
    let store = SignalStore()
    let guestSignaling = InMemorySignaling(user: "guest-user", store: store)
    let guest = TunnelGuestService(
        signaling: guestSignaling,
        hostUser: "host-user",
        tunnelKeyHex: "loopback-tunnel-key",
        bindAddress: "127.0.0.1",
        discover: { _ in nil },
        pollInterval: 0.02,
        timeout: 1
    )
    defer { guest.stop() }

    var didFailToDiscover = false
    do {
        _ = try await guest.connect()
    } catch TunnelError.noPublicEndpoint {
        didFailToDiscover = true
    } catch {
        didFailToDiscover = false
    }

    #expect(didFailToDiscover)
}
