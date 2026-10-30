import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Outcome of a single `TCPSocket.read` call.
public enum ReadResult: Equatable, Sendable {
    case data(Data)
    case timeout
    case closed
}

/// A blocking IPv4 TCP socket, usable both as a listener and as a connected peer.
public final class TCPSocket: @unchecked Sendable {
    private let fd: Int32
    private let lock = NSLock()
    private var closed = false

    private init(fd: Int32) {
        self.fd = fd
    }

    /// Creates a listening socket. Loopback-only binds to 127.0.0.1, otherwise 0.0.0.0.
    public static func listen(port: UInt16 = 0, loopbackOnly: Bool = true) throws -> TCPSocket {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            throw TunnelError.socket(String(cString: strerror(errno)))
        }

        var reuse: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        let bindAddress = loopbackOnly ? "127.0.0.1" : "0.0.0.0"
        guard inet_pton(AF_INET, bindAddress, &address.sin_addr) == 1 else {
            closeDescriptor(descriptor)
            throw TunnelError.socket("invalid bind address: \(bindAddress)")
        }

        let bindResult = withUnsafePointer(to: &address) { pointer -> Int32 in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(descriptor, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            let message = String(cString: strerror(errno))
            closeDescriptor(descriptor)
            throw TunnelError.socket(message)
        }

        #if canImport(Darwin)
        let listenResult = Darwin.listen(descriptor, 16)
        #else
        let listenResult = Glibc.listen(descriptor, 16)
        #endif
        guard listenResult == 0 else {
            let message = String(cString: strerror(errno))
            closeDescriptor(descriptor)
            throw TunnelError.socket(message)
        }

        return TCPSocket(fd: descriptor)
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

    /// Waits up to `timeout` seconds for an incoming connection. Returns nil on timeout or after close.
    public func accept(timeout: TimeInterval) -> TCPSocket? {
        lock.lock()
        let alreadyClosed = closed
        lock.unlock()
        guard !alreadyClosed else { return nil }

        // Poll in short slices: closing the fd from another thread does not wake a poll on macOS.
        let deadline = Date().addingTimeInterval(max(0, timeout))
        var ready = false
        while !ready {
            lock.lock()
            let isClosed = closed
            lock.unlock()
            if isClosed { return nil }

            let slice = max(0, min(deadline.timeIntervalSinceNow, 0.05))
            var pollDescriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let pollResult = poll(&pollDescriptor, 1, Int32(slice * 1000))
            if pollResult > 0 {
                guard pollDescriptor.revents & Int16(POLLIN | POLLHUP) != 0 else { return nil }
                ready = true
            } else if deadline.timeIntervalSinceNow <= 0 {
                return nil
            }
        }

        lock.lock()
        let closedAfterPoll = closed
        lock.unlock()
        guard !closedAfterPoll else { return nil }

        #if canImport(Darwin)
        let newDescriptor = Darwin.accept(fd, nil, nil)
        #else
        let newDescriptor = Glibc.accept(fd, nil, nil)
        #endif
        guard newDescriptor >= 0 else { return nil }

        var noDelay: Int32 = 1
        setsockopt(newDescriptor, Int32(IPPROTO_TCP), TCP_NODELAY, &noDelay, socklen_t(MemoryLayout<Int32>.size))
        TCPSocket.setNoSignal(newDescriptor)

        return TCPSocket(fd: newDescriptor)
    }

    /// Connects to a dotted IPv4 address. Uses a non-blocking connect under the hood so the
    /// timeout is enforced even if the peer never responds.
    public static func connect(host: String = "127.0.0.1", port: UInt16, timeout: TimeInterval = 3) throws -> TCPSocket {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            throw TunnelError.socket(String(cString: strerror(errno)))
        }

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        guard inet_pton(AF_INET, host, &address.sin_addr) == 1 else {
            closeDescriptor(descriptor)
            throw TunnelError.socket("invalid host: \(host)")
        }

        let originalFlags = fcntl(descriptor, F_GETFL, 0)
        _ = fcntl(descriptor, F_SETFL, originalFlags | O_NONBLOCK)

        let connectResult = withUnsafePointer(to: &address) { pointer -> Int32 in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer -> Int32 in
                #if canImport(Darwin)
                return Darwin.connect(descriptor, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
                #else
                return Glibc.connect(descriptor, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
                #endif
            }
        }

        if connectResult != 0 {
            guard errno == EINPROGRESS else {
                let message = String(cString: strerror(errno))
                closeDescriptor(descriptor)
                throw TunnelError.socket(message)
            }

            var pollDescriptor = pollfd(fd: descriptor, events: Int16(POLLOUT), revents: 0)
            let milliseconds = Int32(max(0, min(timeout, Double(Int32.max) / 1000) * 1000))
            let pollResult = poll(&pollDescriptor, 1, milliseconds)
            guard pollResult > 0, pollDescriptor.revents & Int16(POLLOUT) != 0 else {
                closeDescriptor(descriptor)
                throw TunnelError.timeout
            }

            var socketError: Int32 = 0
            var errorLength = socklen_t(MemoryLayout<Int32>.size)
            getsockopt(descriptor, SOL_SOCKET, SO_ERROR, &socketError, &errorLength)
            guard socketError == 0 else {
                closeDescriptor(descriptor)
                throw TunnelError.socket(String(cString: strerror(socketError)))
            }
        }

        _ = fcntl(descriptor, F_SETFL, originalFlags)

        var noDelay: Int32 = 1
        setsockopt(descriptor, Int32(IPPROTO_TCP), TCP_NODELAY, &noDelay, socklen_t(MemoryLayout<Int32>.size))
        TCPSocket.setNoSignal(descriptor)

        return TCPSocket(fd: descriptor)
    }

    /// Waits up to `timeout` seconds for data. `.closed` covers EOF, read errors, and a local close().
    public func read(maxBytes: Int, timeout: TimeInterval) -> ReadResult {
        lock.lock()
        let alreadyClosed = closed
        lock.unlock()
        guard !alreadyClosed else { return .closed }

        var pollDescriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        let milliseconds = Int32(max(0, min(timeout, Double(Int32.max) / 1000) * 1000))
        let pollResult = poll(&pollDescriptor, 1, milliseconds)
        guard pollResult > 0 else { return .timeout }
        guard pollDescriptor.revents & Int16(POLLIN | POLLHUP) != 0 else { return .timeout }

        lock.lock()
        let closedAfterPoll = closed
        lock.unlock()
        guard !closedAfterPoll else { return .closed }

        var buffer = [UInt8](repeating: 0, count: maxBytes)
        let received = recv(fd, &buffer, maxBytes, 0)
        guard received > 0 else { return .closed }

        return .data(Data(buffer[0..<received]))
    }

    /// Loops until all bytes are written. MSG_NOSIGNAL/SO_NOSIGPIPE keep a dead peer from raising SIGPIPE.
    @discardableResult
    public func writeAll(_ data: Data) -> Bool {
        lock.lock()
        let alreadyClosed = closed
        lock.unlock()
        guard !alreadyClosed else { return false }

        var remaining = data
        while !remaining.isEmpty {
            let sent = remaining.withUnsafeBytes { buffer -> Int in
                #if canImport(Darwin)
                return send(fd, buffer.baseAddress, buffer.count, 0)
                #else
                return send(fd, buffer.baseAddress, buffer.count, Int32(MSG_NOSIGNAL))
                #endif
            }
            guard sent > 0 else { return false }
            remaining = remaining.dropFirst(sent)
        }
        return true
    }

    /// Idempotent. Shuts the socket down before closing so a thread blocked in poll/read wakes up promptly.
    public func close() {
        lock.lock()
        defer { lock.unlock() }
        guard !closed else { return }
        closed = true
        shutdown(fd, Int32(SHUT_RDWR))
        Self.closeDescriptor(fd)
    }

    private static func setNoSignal(_ descriptor: Int32) {
        #if canImport(Darwin)
        var value: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &value, socklen_t(MemoryLayout<Int32>.size))
        #endif
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
