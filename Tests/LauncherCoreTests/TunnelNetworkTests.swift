import Foundation
import Testing
@testable import LauncherCore

struct TunnelNetworkTests {
    private let transactionID = Data([0xAA, 0xBB, 0xCC, 0xDD, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77])

    private func header(type: UInt16, length: UInt16) -> Data {
        var data = Data()
        data.append(UInt8(type >> 8))
        data.append(UInt8(type & 0xff))
        data.append(UInt8(length >> 8))
        data.append(UInt8(length & 0xff))
        data.append(contentsOf: [0x21, 0x12, 0xA4, 0x42])
        data.append(transactionID)
        return data
    }

    @Test func requestLayout() {
        let request = STUNClient.makeBindingRequest(transactionID: transactionID)
        #expect(request.count == 20)
        #expect([UInt8](request[0...1]) == [0x00, 0x01])
        #expect([UInt8](request[2...3]) == [0x00, 0x00])
        #expect([UInt8](request[4...7]) == [0x21, 0x12, 0xA4, 0x42])
        #expect(request[8...19] == transactionID)
    }

    @Test func parsesXorMappedAddress() {
        // 203.0.113.9:54321 XORed with the magic cookie.
        var response = header(type: 0x0101, length: 12)
        response.append(contentsOf: [0x00, 0x20, 0x00, 0x08])
        response.append(contentsOf: [0x00, 0x01, 0xF5, 0x23, 0xEA, 0x12, 0xD5, 0x4B])

        let endpoint = STUNClient.parseBindingResponse(response, transactionID: transactionID)
        #expect(endpoint == TunnelEndpoint(host: "203.0.113.9", port: 54321))
    }

    @Test func fallsBackToMappedAddress() {
        // 198.51.100.7:7777, not XORed.
        var response = header(type: 0x0101, length: 12)
        response.append(contentsOf: [0x00, 0x01, 0x00, 0x08])
        response.append(contentsOf: [0x00, 0x01, 0x1E, 0x61, 0xC6, 0x33, 0x64, 0x07])

        let endpoint = STUNClient.parseBindingResponse(response, transactionID: transactionID)
        #expect(endpoint == TunnelEndpoint(host: "198.51.100.7", port: 7777))
    }

    @Test func rejectsWrongTransactionID() {
        var response = header(type: 0x0101, length: 12)
        response.append(contentsOf: [0x00, 0x20, 0x00, 0x08])
        response.append(contentsOf: [0x00, 0x01, 0xF5, 0x23, 0xEA, 0x12, 0xD5, 0x4B])

        let otherID = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C])
        #expect(STUNClient.parseBindingResponse(response, transactionID: otherID) == nil)
    }

    @Test func rejectsTruncatedResponse() {
        var response = header(type: 0x0101, length: 12)
        response.append(contentsOf: [0x00, 0x20, 0x00, 0x08])
        response.append(contentsOf: [0x00, 0x01, 0xF5, 0x23, 0xEA, 0x12, 0xD5, 0x4B])

        let truncated = response.prefix(25)
        #expect(STUNClient.parseBindingResponse(truncated, transactionID: transactionID) == nil)
        #expect(STUNClient.parseBindingResponse(Data([0x01, 0x01]), transactionID: transactionID) == nil)
    }

    @Test func rejectsGarbage() {
        let garbage = Data((0..<40).map { UInt8(($0 * 7 + 3) % 256) })
        #expect(STUNClient.parseBindingResponse(garbage, transactionID: transactionID) == nil)
    }

    @Test func endpointRoundTrip() {
        let endpoint = TunnelEndpoint("1.2.3.4:5678")
        #expect(endpoint?.host == "1.2.3.4")
        #expect(endpoint?.port == 5678)
        #expect(endpoint?.description == "1.2.3.4:5678")
    }

    @Test func endpointRejectsInvalidText() {
        #expect(TunnelEndpoint("no-colon") == nil)
        #expect(TunnelEndpoint("1.2.3.4:abc") == nil)
        #expect(TunnelEndpoint("1.2.3.4:") == nil)
        #expect(TunnelEndpoint(":1234") == nil)
    }

    @Test func udpSocketLoopback() throws {
        let socketA = try UDPSocket(port: 0, bindAddress: "127.0.0.1")
        let socketB = try UDPSocket(port: 0, bindAddress: "127.0.0.1")
        defer {
            socketA.close()
            socketB.close()
        }

        let message = Data("hello tunnel".utf8)
        let destination = TunnelEndpoint(host: "127.0.0.1", port: socketB.localPort)
        socketA.send(message, to: destination)

        let received = socketB.receive(timeout: 1.0)
        #expect(received?.0 == message)
        #expect(received?.1.port == socketA.localPort)

        let start = Date()
        let timedOut = socketB.receive(timeout: 0.1)
        #expect(timedOut == nil)
        #expect(Date().timeIntervalSince(start) < 0.5)
    }
}
