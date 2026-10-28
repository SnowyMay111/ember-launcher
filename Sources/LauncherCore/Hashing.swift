import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

public enum HashingError: Error, Sendable {
    case cryptoKitUnavailable
    case cannotOpenFile
    case fileReadFailed
}

private func hexString<S: Sequence>(_ data: S) -> String where S.Element == UInt8 {
    let hexDigits: [UInt8] = Array("0123456789abcdef".utf8)
    var utf8Bytes = [UInt8]()
    if let underestimated = (data as? (any Collection))?.count {
        utf8Bytes.reserveCapacity(underestimated * 2)
    }
    for byte in data {
        utf8Bytes.append(hexDigits[Int(byte >> 4)])
        utf8Bytes.append(hexDigits[Int(byte & 0x0f)])
    }
    return String(decoding: utf8Bytes, as: UTF8.self)
}

public func sha1Hex(of fileURL: URL) throws -> String {
    #if canImport(CryptoKit)
    let handle: FileHandle
    do {
        handle = try FileHandle(forReadingFrom: fileURL)
    } catch {
        throw HashingError.cannotOpenFile
    }

    defer {
        try? handle.close()
    }

    var hasher = Insecure.SHA1()
    let bufferSize = 1024 * 1024

    while true {
        let chunk: Data
        do {
            guard let readData = try handle.read(upToCount: bufferSize), !readData.isEmpty else {
                break
            }
            chunk = readData
        } catch {
            throw HashingError.fileReadFailed
        }

        hasher.update(data: chunk)
    }

    let digest = hasher.finalize()
    return hexString(digest)
    #else
    throw HashingError.cryptoKitUnavailable
    #endif
}

public func sha256Hex(of fileURL: URL) throws -> String {
    #if canImport(CryptoKit)
    let handle: FileHandle
    do {
        handle = try FileHandle(forReadingFrom: fileURL)
    } catch {
        throw HashingError.cannotOpenFile
    }

    defer {
        try? handle.close()
    }

    var hasher = SHA256()
    let bufferSize = 1024 * 1024

    while true {
        let chunk: Data
        do {
            guard let readData = try handle.read(upToCount: bufferSize), !readData.isEmpty else {
                break
            }
            chunk = readData
        } catch {
            throw HashingError.fileReadFailed
        }

        hasher.update(data: chunk)
    }

    let digest = hasher.finalize()
    return hexString(digest)
    #else
    throw HashingError.cryptoKitUnavailable
    #endif
}

public func sha512Hex(of fileURL: URL) throws -> String {
    #if canImport(CryptoKit)
    let handle: FileHandle
    do {
        handle = try FileHandle(forReadingFrom: fileURL)
    } catch {
        throw HashingError.cannotOpenFile
    }

    defer {
        try? handle.close()
    }

    var hasher = SHA512()
    let bufferSize = 1024 * 1024

    while true {
        let chunk: Data
        do {
            guard let readData = try handle.read(upToCount: bufferSize), !readData.isEmpty else {
                break
            }
            chunk = readData
        } catch {
            throw HashingError.fileReadFailed
        }

        hasher.update(data: chunk)
    }

    let digest = hasher.finalize()
    return hexString(digest)
    #else
    throw HashingError.cryptoKitUnavailable
    #endif
}
