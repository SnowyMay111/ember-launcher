import Foundation

/// Ordered byte stream transport over lossy datagrams.
public final class ReliableStream: @unchecked Sendable {
    private struct Outgoing {
        let packet: Data
        let payload: Data
        var sentAt: TimeInterval?
        var retransmissions: Int
        var wasRetransmitted: Bool
    }

    private let lock = NSLock()
    private let maxPayload: Int
    private let window: Int
    private let start: TimeInterval

    private var nextSequence: UInt32 = 0
    private var lastAcknowledgement: UInt32 = 0
    private var duplicateAcknowledgements = 0
    private var fastRetransmitPending = false

    private var pendingPayloads: [Data] = []
    private var queuedBytesStorage = 0
    private var inFlight: [UInt32: Outgoing] = [:]
    private var inFlightOrder: [UInt32] = []
    private var inFlightBytesStorage = 0

    private var receiveNext: UInt32 = 0
    private var receivedOutOfOrder: [UInt32: Data] = [:]
    private var readBuffer = Data()
    private var acknowledgementNeeded = false

    private var peerClosedStorage = false
    private var closeQueued = false
    private var closeSent = false

    private var srtt: TimeInterval?
    private var rttvar: TimeInterval?

    private var lastReceived: TimeInterval
    private var lastSent: TimeInterval

    public init(
        maxPayload: Int = 1000,
        window: Int = 128,
        start: TimeInterval = 0
    ) {
        precondition(maxPayload > 0)
        precondition(window > 0)
        self.maxPayload = maxPayload
        self.window = window
        self.start = start
        self.lastReceived = start
        self.lastSent = start
    }

    public func send(_ bytes: Data) {
        guard !bytes.isEmpty else { return }

        lock.lock()
        defer { lock.unlock() }

        var offset = 0
        while offset < bytes.count {
            let end = min(offset + maxPayload, bytes.count)
            let payload = bytes.subdata(in: offset..<end)
            pendingPayloads.append(payload)
            queuedBytesStorage += payload.count
            offset = end
        }
    }

    public func receive(packet: Data, now: TimeInterval) {
        guard let type = packet.first else { return }

        lock.lock()
        defer { lock.unlock() }

        switch type {
        case 1:
            guard packet.count >= 5, packet.count <= maxPayload + 5 else { return }
            guard let sequence = Self.readUInt32(packet, at: 1) else { return }

            lastReceived = now
            acknowledgementNeeded = true

            let payload = Data(packet.dropFirst(5))
            if sequence == receiveNext {
                appendReceived(payload)
                receiveNext &+= 1

                while let next = receivedOutOfOrder.removeValue(forKey: receiveNext) {
                    appendReceived(next)
                    receiveNext &+= 1
                }
            } else {
                let distance = sequence &- receiveNext
                let receiveWindow = UInt32(min(window, Int(UInt32.max)))
                if distance < receiveWindow && Self.isAhead(sequence, of: receiveNext) {
                    receivedOutOfOrder[sequence] = payload
                }
            }

        case 2:
            guard packet.count == 9 else { return }
            guard
                let cumulative = Self.readUInt32(packet, at: 1),
                let sack = Self.readUInt32(packet, at: 5)
            else {
                return
            }

            guard !Self.isAhead(cumulative, of: nextSequence) else { return }
            lastReceived = now

            var acknowledged = Set<UInt32>()

            if cumulative == lastAcknowledgement {
                duplicateAcknowledgements += 1
                if duplicateAcknowledgements == 3 && !inFlightOrder.isEmpty {
                    fastRetransmitPending = true
                }
            } else if Self.isAhead(cumulative, of: lastAcknowledgement) {
                lastAcknowledgement = cumulative
                duplicateAcknowledgements = 0

                for sequence in inFlightOrder where Self.isBefore(sequence, cumulative) {
                    acknowledged.insert(sequence)
                }
            }

            for bit in 0..<32 where (sack & (UInt32(1) << UInt32(bit))) != 0 {
                let sequence = cumulative &+ UInt32(bit + 1)
                if Self.isBefore(sequence, nextSequence) {
                    acknowledged.insert(sequence)
                }
            }

            var sample: TimeInterval?
            for sequence in inFlightOrder where acknowledged.contains(sequence) {
                guard let outgoing = inFlight[sequence] else { continue }

                if sample == nil,
                   !outgoing.wasRetransmitted,
                   let sentAt = outgoing.sentAt,
                   now >= sentAt {
                    sample = now - sentAt
                }

                inFlight.removeValue(forKey: sequence)
                inFlightBytesStorage -= outgoing.payload.count
            }

            if !acknowledged.isEmpty {
                inFlightOrder.removeAll { acknowledged.contains($0) }
            }

            if let sample {
                updateRTT(sample)
            }

        case 3:
            guard packet.count == 1 else { return }
            lastReceived = now

        case 4:
            guard packet.count == 1 else { return }
            lastReceived = now
            peerClosedStorage = true

        default:
            return
        }
    }

    public func pendingPackets(now: TimeInterval) -> [Data] {
        lock.lock()
        defer { lock.unlock() }

        var packets: [Data] = []
        var returnedSequences = Set<UInt32>()

        if fastRetransmitPending, let sequence = inFlightOrder.first {
            if let packet = retransmit(sequence, now: now) {
                packets.append(packet)
                returnedSequences.insert(sequence)
            }
            fastRetransmitPending = false
        }

        for sequence in inFlightOrder {
            guard !returnedSequences.contains(sequence),
                  let outgoing = inFlight[sequence],
                  let sentAt = outgoing.sentAt
            else {
                continue
            }

            let timeout = retransmissionTimeout(for: outgoing)
            guard now >= sentAt + timeout else { continue }

            if let packet = retransmit(sequence, now: now) {
                packets.append(packet)
                returnedSequences.insert(sequence)
            }
        }

        while inFlightOrder.count < window, !pendingPayloads.isEmpty {
            let payload = pendingPayloads.removeFirst()
            let sequence = nextSequence
            nextSequence &+= 1

            var packet = Data([1])
            Self.appendUInt32(sequence, to: &packet)
            packet.append(payload)

            inFlight[sequence] = Outgoing(
                packet: packet,
                payload: payload,
                sentAt: now,
                retransmissions: 0,
                wasRetransmitted: false
            )
            inFlightOrder.append(sequence)
            inFlightBytesStorage += payload.count
            queuedBytesStorage -= payload.count
            lastSent = now
            packets.append(packet)
        }

        if closeQueued, !closeSent {
            closeSent = true
            lastSent = now
            packets.append(Data([4]))
        }

        if acknowledgementNeeded {
            acknowledgementNeeded = false
            var packet = Data([2])
            Self.appendUInt32(receiveNext, to: &packet)

            var sack: UInt32 = 0
            for bit in 0..<32 {
                let sequence = receiveNext &+ UInt32(bit + 1)
                if receivedOutOfOrder[sequence] != nil {
                    sack |= UInt32(1) << UInt32(bit)
                }
            }
            Self.appendUInt32(sack, to: &packet)

            lastSent = now
            packets.append(packet)
        }

        if packets.isEmpty, now - lastSent >= 5 {
            lastSent = now
            packets.append(Data([3]))
        }

        return packets
    }

    public func readAvailable() -> Data {
        lock.lock()
        defer { lock.unlock() }

        let result = readBuffer
        readBuffer.removeAll(keepingCapacity: true)
        return result
    }

    public var peerClosed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return peerClosedStorage
    }

    public func close() {
        lock.lock()
        defer { lock.unlock() }
        closeQueued = true
    }

    public var isIdleTooLong: (TimeInterval) -> Bool {
        { [weak self] now in
            guard let self else { return true }
            self.lock.lock()
            defer { self.lock.unlock() }
            return now - self.lastReceived > 30
        }
    }

    public func isIdleTooLong(now: TimeInterval) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return now - lastReceived > 30
    }

    public var bytesInFlight: Int {
        lock.lock()
        defer { lock.unlock() }
        return inFlightBytesStorage
    }

    public var queuedBytes: Int {
        lock.lock()
        defer { lock.unlock() }
        return queuedBytesStorage
    }

    private func appendReceived(_ payload: Data) {
        readBuffer.append(payload)
    }

    private func retransmit(_ sequence: UInt32, now: TimeInterval) -> Data? {
        guard var outgoing = inFlight[sequence] else { return nil }

        outgoing.sentAt = now
        outgoing.retransmissions += 1
        outgoing.wasRetransmitted = true
        inFlight[sequence] = outgoing
        lastSent = now
        return outgoing.packet
    }

    private var retransmissionBase: TimeInterval {
        guard let srtt, let rttvar else { return 0.5 }
        return min(max(srtt + 4 * rttvar, 0.2), 3.0)
    }

    private func retransmissionTimeout(for outgoing: Outgoing) -> TimeInterval {
        var timeout = retransmissionBase
        for _ in 0..<outgoing.retransmissions {
            timeout = min(timeout * 2, 3.0)
        }
        return min(timeout, 3.0)
    }

    private func updateRTT(_ sample: TimeInterval) {
        if let currentSRTT = srtt, let currentRTTVar = rttvar {
            rttvar = 0.75 * currentRTTVar + 0.25 * abs(currentSRTT - sample)
            srtt = 0.875 * currentSRTT + 0.125 * sample
        } else {
            srtt = sample
            rttvar = sample / 2
        }
    }

    private static func isBefore(_ lhs: UInt32, _ rhs: UInt32) -> Bool {
        lhs != rhs && (rhs &- lhs) < 0x80000000
    }

    private static func isAhead(_ lhs: UInt32, of rhs: UInt32) -> Bool {
        isBefore(rhs, lhs)
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= data.count else { return nil }

        return
            (UInt32(data[offset]) << 24) |
            (UInt32(data[offset + 1]) << 16) |
            (UInt32(data[offset + 2]) << 8) |
            UInt32(data[offset + 3])
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(UInt8((value >> 24) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8(value & 0xff))
    }
}
