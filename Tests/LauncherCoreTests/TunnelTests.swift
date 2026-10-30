import Foundation
import Testing
@testable import LauncherCore

#if canImport(CryptoKit)
struct TunnelCipherTests {
    @Test func testRoundTripInBothDirections() {
        let host = TunnelCipher(tunnelKeyHex: "test-tunnel-key", isHost: true)
        let guest = TunnelCipher(tunnelKeyHex: "test-tunnel-key", isHost: false)
        let plaintext = Data("hello through the tunnel".utf8)

        #expect(guest.open(host.seal(plaintext)) == plaintext)
        #expect(host.open(guest.seal(plaintext)) == plaintext)
    }

    @Test func testTamperingIsRejected() {
        let host = TunnelCipher(tunnelKeyHex: "test-tunnel-key", isHost: true)
        let guest = TunnelCipher(tunnelKeyHex: "test-tunnel-key", isHost: false)

        var datagram = host.seal(Data("secret".utf8))
        datagram[datagram.count - 1] ^= 1

        #expect(guest.open(datagram) == nil)
    }

    @Test func testWrongKeyIsRejected() {
        let host = TunnelCipher(tunnelKeyHex: "test-tunnel-key", isHost: true)
        let guest = TunnelCipher(tunnelKeyHex: "different-key", isHost: false)

        #expect(guest.open(host.seal(Data("secret".utf8))) == nil)
    }

    @Test func testOwnDirectionIsRejected() {
        let host = TunnelCipher(tunnelKeyHex: "test-tunnel-key", isHost: true)
        let datagram = host.seal(Data("secret".utf8))

        #expect(host.open(datagram) == nil)
    }
}
#endif

private struct Flight {
    let packet: Data
    let deliverAt: Int
    let toA: Bool
}

private struct LossyLink {
    private var state: UInt64
    private var flights: [Flight] = []

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func submit(_ packets: [Data], toA: Bool, now: Int) {
        for packet in packets {
            let value = nextRandom()
            if value % 10 < 2 {
                continue
            }

            let reordered = (value / 10) % 5 == 0
            let delay = reordered ? 3 : 0
            flights.append(Flight(packet: packet, deliverAt: now + delay, toA: toA))
        }
    }

    mutating func deliver(now: Int) -> [Flight] {
        var ready: [Flight] = []
        var waiting: [Flight] = []

        for flight in flights {
            if flight.deliverAt <= now {
                ready.append(flight)
            } else {
                waiting.append(flight)
            }
        }

        flights = waiting
        return ready
    }

    private mutating func nextRandom() -> UInt32 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return UInt32(truncatingIfNeeded: state >> 32)
    }
}

struct ReliableStreamTests {
    @Test func testLargeTransferAcrossLossyReorderedLink() {
        var source = Data(capacity: 200_000)
        for index in 0..<200_000 {
            source.append(UInt8(truncatingIfNeeded: index &* 31))
        }

        let sender = ReliableStream(start: 0)
        let receiver = ReliableStream(start: 0)
        sender.send(source)

        var link = LossyLink(seed: 0x1234_5678)
        var received = Data()

        for step in 0..<20_000 {
            let now = Double(step) * 0.01
            link.submit(sender.pendingPackets(now: now), toA: false, now: step)
            link.submit(receiver.pendingPackets(now: now), toA: true, now: step)

            for flight in link.deliver(now: step) {
                if flight.toA {
                    sender.receive(packet: flight.packet, now: now)
                } else {
                    receiver.receive(packet: flight.packet, now: now)
                }
            }

            received.append(receiver.readAvailable())
            if received.count == source.count {
                break
            }
        }

        #expect(received == source)
    }

    @Test func testBidirectionalTransfer() {
        let leftBytes = Data((0..<12_000).map { UInt8(truncatingIfNeeded: $0 * 7) })
        let rightBytes = Data((0..<9_000).map { UInt8(truncatingIfNeeded: $0 * 13) })

        let left = ReliableStream(start: 0)
        let right = ReliableStream(start: 0)
        left.send(leftBytes)
        right.send(rightBytes)

        var link = LossyLink(seed: 0xabcdef01)
        var receivedLeft = Data()
        var receivedRight = Data()

        for step in 0..<10_000 {
            let now = Double(step) * 0.01
            link.submit(left.pendingPackets(now: now), toA: false, now: step)
            link.submit(right.pendingPackets(now: now), toA: true, now: step)

            for flight in link.deliver(now: step) {
                if flight.toA {
                    left.receive(packet: flight.packet, now: now)
                } else {
                    right.receive(packet: flight.packet, now: now)
                }
            }

            receivedLeft.append(left.readAvailable())
            receivedRight.append(right.readAvailable())

            if receivedLeft.count == rightBytes.count && receivedRight.count == leftBytes.count {
                break
            }
        }

        #expect(receivedLeft == rightBytes)
        #expect(receivedRight == leftBytes)
    }

    @Test func testClosePropagates() {
        let sender = ReliableStream(start: 0)
        let receiver = ReliableStream(start: 0)

        sender.close()
        for packet in sender.pendingPackets(now: 0) {
            receiver.receive(packet: packet, now: 0)
        }

        #expect(receiver.peerClosed)
    }

    @Test func testIdleTimeout() {
        let stream = ReliableStream(start: 0)

        #expect(!stream.isIdleTooLong(now: 30))
        #expect(stream.isIdleTooLong(now: 31))
    }
} 
