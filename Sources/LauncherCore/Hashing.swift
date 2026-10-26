import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

public enum HashingError: Error, Sendable {
    case cryptoKitUnavailable
    case cannotOpenFile
    case fileReadFailed
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
    return digest.map { String(format: "%02x", $0) }.joined()
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
    return digest.map { String(format: "%02x", $0) }.joined()
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
    return digest.map { String(format: "%02x", $0) }.joined()
    #else
    throw HashingError.cryptoKitUnavailable
    #endif
}
