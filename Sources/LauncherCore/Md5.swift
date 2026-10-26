import Foundation
#if canImport(CryptoKit)
import CryptoKit

func md5(_ data: Data) -> [UInt8] {
    let digest = Insecure.MD5.hash(data: data)
    return Array(digest)
}
#endif
