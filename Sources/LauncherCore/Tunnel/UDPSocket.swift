import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Errors raised by the tunnel networking primitives.
public enum TunnelError: Error {
    case socket(String)
    case timeout
    case noPublicEndpoint
    case handshakeFailed
    case closed
}

/// An IPv4 host/port pair, e.g. a peer's public address as seen through NAT.
public struct TunnelEndpoint: Hashable, Codable, Sendable, CustomStringConvertible {
    public let host: String
    public let port: UInt16

    public init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }

    /// Parses "1.2.3.4:5678". Returns nil for anything else.
    public init?(_ text: String) {
        guard let colonIndex = text.lastIndex(of: ":") else { return nil }
        let hostPart = String(text[text.startIndex..<colonIndex])
        let portPart = String(text[text.index(after: colonIndex)...])
        guard let port = UInt16(portPart), !hostPart.isEmpty else { return nil }
        self.host = hostPart
        self.port = port
    }

    public var description: String {
        "\(host):\(port)"
    }
}

/// A blocking IPv4 UDP socket.
public final class UDPSocket: @unchecked Sendable {
    private let fd: Int32
    private let lock = NSLock()
    private var closed = false

    public init(port: UInt16 = 0, bindAddress: String = "0.0.0.0") throws {
        let descriptor = socket(AF_INET, SOCK_DGRAM, 0)
        guard descriptor >= 0 else {
            throw TunnelError.socket(String(cString: strerror(errno)))
        }

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        guard inet_pton(AF_INET, bindAddress, &address.sin_addr) == 1 else {
            Self.closeDescriptor(descriptor)
            throw TunnelError.socket("invalid bind address: \(bindAddress)")
        }

        let bindResult = withUnsafePointer(to: &address) { pointer -> Int32 in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(descriptor, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            let message = String(cString: strerror(errno))
            Self.closeDescriptor(descriptor)
            throw TunnelError.socket(message)
        }

        self.fd = descriptor
    }

    public var localPort: UInt16 {
        var address = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let result = withUnsafeMutablePointer(to: &address) { pointer -> Int32 in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                getsockname(fd, sockaddrPointer, &length)
            }
        }
        guard result == 0 else { return 0 }
        return UInt16(bigEndian: address.sin_port)
    }

    /// Best effort send; errors are ignored since datagrams are inherently unreliable.
    public func send(_ data: Data, to endpoint: TunnelEndpoint) {
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = endpoint.port.bigEndian
        guard inet_pton(AF_INET, endpoint.host, &address.sin_addr) == 1 else { return }

        _ = data.withUnsafeBytes { buffer -> Int in
            withUnsafePointer(to: &address) { pointer -> Int in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                    sendto(fd, buffer.baseAddress, buffer.count, 0, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }

    /// Waits up to `timeout` seconds for a datagram. Returns nil on timeout or after close.
    public func receive(timeout: TimeInterval) -> (Data, TunnelEndpoint)? {
        lock.lock()
        let alreadyClosed = closed
        lock.unlock()
        guard !alreadyClosed else { return nil }

        var pollDescriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        let milliseconds = Int32(max(0, min(timeout, Double(Int32.max) / 1000) * 1000))
        let pollResult = poll(&pollDescriptor, 1, milliseconds)
        guard pollResult > 0, pollDescriptor.revents & Int16(POLLIN) != 0 else { return nil }

        lock.lock()
        let closedAfterPoll = closed
        lock.unlock()
        guard !closedAfterPoll else { return nil }

        var buffer = [UInt8](repeating: 0, count: 2048)
        var address = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)

        let received = withUnsafeMutablePointer(to: &address) { pointer -> Int in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                recvfrom(fd, &buffer, buffer.count, 0, sockaddrPointer, &length)
            }
        }
        guard received > 0 else { return nil }

        var hostBuffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        inet_ntop(AF_INET, &address.sin_addr, &hostBuffer, socklen_t(hostBuffer.count))
        let endpoint = TunnelEndpoint(host: String(cString: hostBuffer), port: UInt16(bigEndian: address.sin_port))

        return (Data(buffer[0..<received]), endpoint)
    }

    /// Idempotent. A receive blocked in poll() still returns within its own timeout.
    public func close() {
        lock.lock()
        defer { lock.unlock() }
        guard !closed else { return }
        closed = true
        Self.closeDescriptor(fd)
    }

    private static func closeDescriptor(_ descriptor: Int32) {
        #if canImport(Darwin)
        Darwin.close(descriptor)
        #else
        Glibc.close(descriptor)
        #endif
    }

    deinit {
        close()
    }
}
