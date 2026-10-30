import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Minimal RFC 5389 STUN client used to discover a socket's public endpoint through NAT.
public enum STUNClient {
    public static let defaultServers = [
        "stun.l.google.com:19302",
        "stun1.l.google.com:19302",
        "stun.cloudflare.com:3478",
    ]

    private static let magicCookie: UInt32 = 0x2112_A442
    private static let bindingRequestType: UInt16 = 0x0001
    private static let bindingSuccessType: UInt16 = 0x0101
    private static let attributeMappedAddress: UInt16 = 0x0001
    private static let attributeXorMappedAddress: UInt16 = 0x0020

    public static func makeBindingRequest(transactionID: Data) -> Data {
        precondition(transactionID.count == 12)

        var packet = Data()
        appendUInt16(bindingRequestType, to: &packet)
        appendUInt16(0, to: &packet)
        appendUInt32(magicCookie, to: &packet)
        packet.append(transactionID)
        return packet
    }

    /// Reads the success response, preferring XOR-MAPPED-ADDRESS over MAPPED-ADDRESS. Never crashes on bad input.
    public static func parseBindingResponse(_ data: Data, transactionID: Data) -> TunnelEndpoint? {
        guard data.count >= 20 else { return nil }
        let bytes = [UInt8](data)

        let type = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
        let length = Int(UInt16(bytes[2]) << 8 | UInt16(bytes[3]))
        let cookie = readUInt32(bytes, at: 4)
        guard type == bindingSuccessType, cookie == magicCookie else { return nil }
        guard bytes.count >= 20 + length else { return nil }
        guard Data(bytes[8..<20]) == transactionID else { return nil }

        var offset = 20
        let end = 20 + length
        var mapped: TunnelEndpoint?
        var xorMapped: TunnelEndpoint?

        while offset + 4 <= end {
            let attributeType = UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
            let attributeLength = Int(UInt16(bytes[offset + 2]) << 8 | UInt16(bytes[offset + 3]))
            let valueStart = offset + 4
            guard valueStart + attributeLength <= end else { break }

            if attributeType == attributeXorMappedAddress, attributeLength >= 8, bytes[valueStart + 1] == 0x01 {
                let xorPort = UInt16(bytes[valueStart + 2]) << 8 | UInt16(bytes[valueStart + 3])
                let port = xorPort ^ UInt16(magicCookie >> 16)
                let address = readUInt32(bytes, at: valueStart + 4) ^ magicCookie
                xorMapped = TunnelEndpoint(host: addressString(address), port: port)
            } else if attributeType == attributeMappedAddress, attributeLength >= 8, bytes[valueStart + 1] == 0x01 {
                let port = UInt16(bytes[valueStart + 2]) << 8 | UInt16(bytes[valueStart + 3])
                let address = readUInt32(bytes, at: valueStart + 4)
                mapped = TunnelEndpoint(host: addressString(address), port: port)
            }

            let padded = attributeLength + ((4 - attributeLength % 4) % 4)
            offset = valueStart + padded
        }

        return xorMapped ?? mapped
    }

    /// Sends the binding request from `socket` itself so the NAT mapping it discovers belongs to that socket.
    public static func discover(
        using socket: UDPSocket,
        servers: [String] = defaultServers,
        perServerTimeout: TimeInterval = 1.5
    ) -> TunnelEndpoint? {
        var generator = SystemRandomNumberGenerator()
        let transactionID = Data((0..<12).map { _ in UInt8.random(in: 0...255, using: &generator) })
        let request = makeBindingRequest(transactionID: transactionID)

        for server in servers {
            guard let endpoints = resolve(server) else { continue }

            for _ in 0..<2 {
                for endpoint in endpoints {
                    socket.send(request, to: endpoint)
                }

                let deadline = Date().addingTimeInterval(perServerTimeout)
                while Date() < deadline {
                    let remaining = deadline.timeIntervalSinceNow
                    guard remaining > 0, let (data, from) = socket.receive(timeout: remaining) else { break }
                    guard endpoints.contains(from) else { continue }
                    if let result = parseBindingResponse(data, transactionID: transactionID) {
                        return result
                    }
                }
            }
        }

        return nil
    }

    private static func resolve(_ server: String) -> [TunnelEndpoint]? {
        guard let colonIndex = server.lastIndex(of: ":") else { return nil }
        let host = String(server[server.startIndex..<colonIndex])
        guard let port = UInt16(server[server.index(after: colonIndex)...]) else { return nil }

        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_DGRAM

        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &result) == 0, let first = result else { return nil }
        defer { freeaddrinfo(result) }

        var endpoints: [TunnelEndpoint] = []
        var current: UnsafeMutablePointer<addrinfo>? = first
        while let info = current {
            if info.pointee.ai_family == AF_INET, let addr = info.pointee.ai_addr {
                let address = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                var addressCopy = address.sin_addr
                var hostBuffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                inet_ntop(AF_INET, &addressCopy, &hostBuffer, socklen_t(hostBuffer.count))
                endpoints.append(TunnelEndpoint(host: String(cString: hostBuffer), port: port))
            }
            current = info.pointee.ai_next
        }

        return endpoints.isEmpty ? nil : endpoints
    }

    private static func readUInt32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        (UInt32(bytes[offset]) << 24) | (UInt32(bytes[offset + 1]) << 16) | (UInt32(bytes[offset + 2]) << 8) | UInt32(bytes[offset + 3])
    }

    private static func addressString(_ value: UInt32) -> String {
        "\((value >> 24) & 0xff).\((value >> 16) & 0xff).\((value >> 8) & 0xff).\(value & 0xff)"
    }

    private static func appendUInt16(_ value: UInt16, to data: inout Data) {
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8(value & 0xff))
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(UInt8((value >> 24) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8(value & 0xff))
    }
}
