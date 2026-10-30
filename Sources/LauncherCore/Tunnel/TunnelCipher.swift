import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// ChaChaPoly protection for UDP datagrams.
public struct TunnelCipher: Sendable {
    private final class CounterBox: @unchecked Sendable {
        private let lock = NSLock()
        private var value: UInt64 = 1

        func next() -> UInt64 {
            lock.lock()
            defer { lock.unlock() }
            let current = value
            value &+= 1
            return current
        }
    }

    private let key: Data
    private let direction: UInt8
    private let counter: CounterBox

    public init(tunnelKeyHex: String, isHost: Bool) {
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: Data(tunnelKeyHex.utf8))
        self.key = Data(digest)
        #else
        self.key = Data()
        #endif
        self.direction = isHost ? 0 : 1
        self.counter = CounterBox()

        #if !canImport(CryptoKit)
        fatalError("TunnelCipher needs CryptoKit; add a portable implementation for Windows")
        #endif
    }

    public func seal(_ plaintext: Data) -> Data {
        #if canImport(CryptoKit)
        let value = counter.next()
        let nonceData = makeNonce(direction: direction, counter: value)
        let nonce = try! ChaChaPoly.Nonce(data: nonceData)
        let sealed = try! ChaChaPoly.seal(
            plaintext,
            using: SymmetricKey(data: key),
            nonce: nonce
        )

        // Transmit the counter plus ciphertext+tag; the nonce itself is derived
        // from the counter on the receiving end rather than sent on the wire.
        var datagram = Data()
        appendUInt64(value, to: &datagram)
        datagram.append(sealed.ciphertext)
        datagram.append(sealed.tag)
        return datagram
        #else
        fatalError("TunnelCipher needs CryptoKit; add a portable implementation for Windows")
        #endif
    }

    public func open(_ rawDatagram: Data) -> Data? {
        #if canImport(CryptoKit)
        // Normalize to a zero-based Data so index arithmetic below is simple.
        let datagram = Data(rawDatagram)
        guard datagram.count >= 8 + 16 else { return nil }

        let value = readUInt64(datagram, at: 0)
        let nonceData = makeNonce(direction: direction ^ 1, counter: value)
        guard let nonce = try? ChaChaPoly.Nonce(data: nonceData) else {
            return nil
        }

        let tagStart = datagram.count - 16
        let ciphertext = datagram.subdata(in: 8..<tagStart)
        let tag = datagram.subdata(in: tagStart..<datagram.count)

        guard let sealed = try? ChaChaPoly.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag) else {
            return nil
        }

        return try? ChaChaPoly.open(
            sealed,
            using: SymmetricKey(data: key)
        )
        #else
        fatalError("TunnelCipher needs CryptoKit; add a portable implementation for Windows")
        #endif
    }

    private func makeNonce(direction: UInt8, counter: UInt64) -> Data {
        var nonce = Data([direction, 0, 0, 0])
        appendUInt64(counter, to: &nonce)
        return nonce
    }

    private func appendUInt64(_ value: UInt64, to data: inout Data) {
        data.append(UInt8((value >> 56) & 0xff))
        data.append(UInt8((value >> 48) & 0xff))
        data.append(UInt8((value >> 40) & 0xff))
        data.append(UInt8((value >> 32) & 0xff))
        data.append(UInt8((value >> 24) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8(value & 0xff))
    }

    private func readUInt64(_ data: Data, at offset: Int) -> UInt64 {
        var value: UInt64 = 0
        for index in 0..<8 {
            value = (value << 8) | UInt64(data[offset + index])
        }
        return value
    }
}
