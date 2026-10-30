import Foundation

/// Multiplexes several logical byte channels over one reliable stream.
public struct TunnelFrame: Equatable, Sendable {
    public enum Kind: UInt8, Sendable {
        case open = 1
        case data = 2
        case close = 3
    }

    public let kind: Kind
    public let channel: UInt32
    public let payload: Data

    public init(kind: Kind, channel: UInt32, payload: Data) {
        self.kind = kind
        self.channel = channel
        self.payload = payload
    }
}

public struct TunnelFrameCodec: Sendable {
    public static let maxPayloadSize = 16384
    public static let maxChunkSize = 1400
    private static let headerSize = 7

    public static func encode(_ frame: TunnelFrame) -> Data {
        precondition(frame.payload.count <= maxPayloadSize)

        var data = Data(capacity: headerSize + frame.payload.count)
        data.append(frame.kind.rawValue)
        appendUInt32(frame.channel, to: &data)
        appendUInt16(UInt16(frame.payload.count), to: &data)
        data.append(frame.payload)
        return data
    }

    /// Splits arbitrary bytes into data frames no larger than maxChunkSize.
    public static func chunks(for channel: UInt32, bytes: Data) -> [TunnelFrame] {
        guard !bytes.isEmpty else { return [] }

        var frames: [TunnelFrame] = []
        var offset = 0
        while offset < bytes.count {
            let end = min(offset + maxChunkSize, bytes.count)
            let payload = bytes.subdata(in: offset..<end)
            frames.append(TunnelFrame(kind: .data, channel: channel, payload: payload))
            offset = end
        }
        return frames
    }

    /// Reassembles frames from a reliable byte stream, buffering partial data across feeds.
    public struct Decoder {
        private var buffer = Data()
        public private(set) var isCorrupt = false

        public init() {}

        public mutating func feed(_ bytes: Data) -> [TunnelFrame] {
            guard !isCorrupt else { return [] }

            buffer.append(bytes)

            var frames: [TunnelFrame] = []
            while true {
                let base = buffer.startIndex
                guard buffer.count >= headerSize else { break }

                guard let kind = TunnelFrame.Kind(rawValue: buffer[base]) else {
                    isCorrupt = true
                    buffer.removeAll()
                    return []
                }

                let channel = readUInt32(buffer, at: base + 1)
                let length = Int(readUInt16(buffer, at: base + 5))
                guard length <= maxPayloadSize else {
                    isCorrupt = true
                    buffer.removeAll()
                    return []
                }

                guard buffer.count >= headerSize + length else { break }

                let payloadStart = base + headerSize
                let payloadEnd = payloadStart + length
                let payload = buffer.subdata(in: payloadStart..<payloadEnd)

                frames.append(TunnelFrame(kind: kind, channel: channel, payload: payload))
                buffer.removeSubrange(base..<payloadEnd)
            }

            return frames
        }
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(UInt8((value >> 24) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8(value & 0xff))
    }

    private static func appendUInt16(_ value: UInt16, to data: inout Data) {
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8(value & 0xff))
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        (UInt32(data[offset]) << 24) |
        (UInt32(data[offset + 1]) << 16) |
        (UInt32(data[offset + 2]) << 8) |
        UInt32(data[offset + 3])
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        (UInt16(data[offset]) << 8) |
        UInt16(data[offset + 1])
    }
}
