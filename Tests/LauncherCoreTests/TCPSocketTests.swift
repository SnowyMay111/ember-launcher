import Foundation
import Testing
@testable import LauncherCore

struct TCPSocketTests {

    @Test func echoRoundTripBothDirections() throws {
        let listener = try TCPSocket.listen()
        let port = listener.localPort

        // Background echo server: whatever it reads, it writes straight back.
        let serverThread = Thread {
            guard let serverSide = listener.accept(timeout: 5) else { return }
            while true {
                switch serverSide.read(maxBytes: 65536, timeout: 5) {
                case .data(let chunk):
                    _ = serverSide.writeAll(chunk)
                case .timeout:
                    continue
                case .closed:
                    return
                }
            }
        }
        serverThread.start()

        let client = try TCPSocket.connect(port: port)
        let payload = Data((0..<(100 * 1024)).map { UInt8($0 % 256) })

        #expect(client.writeAll(payload))

        var received = Data()
        while received.count < payload.count {
            switch client.read(maxBytes: 65536, timeout: 5) {
            case .data(let chunk):
                received.append(chunk)
            case .timeout:
                Issue.record("unexpected timeout while reading echo")
                return
            case .closed:
                Issue.record("unexpected close while reading echo")
                return
            }
        }

        #expect(received == payload)

        client.close()
        listener.close()
    }

    @Test func readTimesOutWhenNoData() throws {
        let listener = try TCPSocket.listen()
        let client = try TCPSocket.connect(port: listener.localPort)
        guard let server = listener.accept(timeout: 5) else {
            Issue.record("accept failed")
            return
        }
        _ = server

        #expect(client.read(maxBytes: 1024, timeout: 0.2) == .timeout)

        client.close()
        listener.close()
    }

    @Test func peerCloseReportsClosed() throws {
        let listener = try TCPSocket.listen()
        let client = try TCPSocket.connect(port: listener.localPort)
        guard let server = listener.accept(timeout: 5) else {
            Issue.record("accept failed")
            return
        }

        server.close()

        #expect(client.read(maxBytes: 1024, timeout: 5) == .closed)

        client.close()
        listener.close()
    }

    @Test func acceptTimesOutWithNoConnection() throws {
        let listener = try TCPSocket.listen()
        #expect(listener.accept(timeout: 0.2) == nil)
        listener.close()
    }

    @Test func closeUnblocksPendingAccept() throws {
        let listener = try TCPSocket.listen()

        let closerThread = Thread {
            Thread.sleep(forTimeInterval: 0.1)
            listener.close()
        }
        closerThread.start()

        let start = Date()
        let result = listener.accept(timeout: 5)
        let elapsed = Date().timeIntervalSince(start)

        #expect(result == nil)
        #expect(elapsed < 1.0)
    }
}
