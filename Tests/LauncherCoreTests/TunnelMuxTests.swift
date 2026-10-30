import Testing
import Foundation
@testable import LauncherCore

struct TunnelMuxTests {
    @Test func roundtripOpen() {
        let frame = TunnelFrame(kind: .open, channel: 7, payload: Data([1, 2, 3]))
        var decoder = TunnelFrameCodec.Decoder()
        let frames = decoder.feed(TunnelFrameCodec.encode(frame))
        #expect(frames == [frame])
    }

    @Test func roundtripData() {
        let frame = TunnelFrame(kind: .data, channel: 42, payload: Data(repeating: 9, count: 1000))
        var decoder = TunnelFrameCodec.Decoder()
        let frames = decoder.feed(TunnelFrameCodec.encode(frame))
        #expect(frames == [frame])
    }

    @Test func roundtripClose() {
        let frame = TunnelFrame(kind: .close, channel: 3, payload: Data())
        var decoder = TunnelFrameCodec.Decoder()
        let frames = decoder.feed(TunnelFrameCodec.encode(frame))
        #expect(frames == [frame])
    }

    @Test func byteByByteFeeding() {
        let frame = TunnelFrame(kind: .data, channel: 5, payload: Data([10, 20, 30, 40]))
        let encoded = TunnelFrameCodec.encode(frame)

        var decoder = TunnelFrameCodec.Decoder()
        var decoded: [TunnelFrame] = []
        for byte in encoded {
            decoded.append(contentsOf: decoder.feed(Data([byte])))
        }
        #expect(decoded == [frame])
    }

    @Test func twoFramesInOneFeed() {
        let first = TunnelFrame(kind: .open, channel: 1, payload: Data())
        let second = TunnelFrame(kind: .data, channel: 1, payload: Data([5, 6, 7]))

        var combined = TunnelFrameCodec.encode(first)
        combined.append(TunnelFrameCodec.encode(second))

        var decoder = TunnelFrameCodec.Decoder()
        let frames = decoder.feed(combined)
        #expect(frames == [first, second])
    }

    @Test func corruptKindMarksCorrupt() {
        var bytes = Data([99])
        bytes.append(Data([0, 0, 0, 1]))
        bytes.append(Data([0, 0]))

        var decoder = TunnelFrameCodec.Decoder()
        let frames = decoder.feed(bytes)
        #expect(frames.isEmpty)
        #expect(decoder.isCorrupt)
        #expect(decoder.feed(Data([1])).isEmpty)
    }

    @Test func oversizeLengthMarksCorrupt() {
        var bytes = Data([TunnelFrame.Kind.data.rawValue])
        bytes.append(Data([0, 0, 0, 1]))
        bytes.append(Data([0xff, 0xff]))

        var decoder = TunnelFrameCodec.Decoder()
        let frames = decoder.feed(bytes)
        #expect(frames.isEmpty)
        #expect(decoder.isCorrupt)
    }

    @Test func chunksReassembleToOriginalBytes() {
        for size in [0, 1, 1400, 1401, 100000] {
            let original = Data((0..<size).map { UInt8($0 % 256) })
            let frames = TunnelFrameCodec.chunks(for: 1, bytes: original)

            var reassembled = Data()
            for frame in frames {
                #expect(frame.payload.count <= TunnelFrameCodec.maxChunkSize)
                reassembled.append(frame.payload)
            }
            #expect(reassembled == original)
        }
    }
}
