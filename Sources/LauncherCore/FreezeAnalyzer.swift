import Foundation

public enum JavaArchitecture: String, Codable, Sendable {
    case arm64Native
    case rosetta
    case x86_64Native
    case unknown
}

public struct FreezeStats: Codable, Sendable, Equatable {
    public var minorStutterCount: Int
    public var criticalFreezeCount: Int
    public var maxPauseMs: Double
    public var fullGCCount: Int
    public var allocationStallCount: Int
    public var outOfMemoryCount: Int
    public var lastUptimeSeconds: Double
    public var maxHeapOccupancyRatio: Double
    public var averageHeapOccupancyRatio: Double
    public var tickDropCount: Int
    public var maxTickBehindMs: Int

    public init(
        minorStutterCount: Int = 0,
        criticalFreezeCount: Int = 0,
        maxPauseMs: Double = 0,
        fullGCCount: Int = 0,
        allocationStallCount: Int = 0,
        outOfMemoryCount: Int = 0,
        lastUptimeSeconds: Double = 0,
        maxHeapOccupancyRatio: Double = 0,
        averageHeapOccupancyRatio: Double = 0,
        tickDropCount: Int = 0,
        maxTickBehindMs: Int = 0
    ) {
        self.minorStutterCount = minorStutterCount
        self.criticalFreezeCount = criticalFreezeCount
        self.maxPauseMs = maxPauseMs
        self.fullGCCount = fullGCCount
        self.allocationStallCount = allocationStallCount
        self.outOfMemoryCount = outOfMemoryCount
        self.lastUptimeSeconds = lastUptimeSeconds
        self.maxHeapOccupancyRatio = maxHeapOccupancyRatio
        self.averageHeapOccupancyRatio = averageHeapOccupancyRatio
        self.tickDropCount = tickDropCount
        self.maxTickBehindMs = maxTickBehindMs
    }
}

public struct FreezeAnalyzer: Sendable {
    public static let warmupSeconds: Double = 60.0

    private static let tickDropRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"Can't keep up! Is the server overloaded\? Running (\d+)ms or (\d+) ticks behind"#,
            options: []
        )
    }()

    private static let gcDurationRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)ms\s*$"#, options: [])
    }()

    private static let heapRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"(\d+(?:\.\d+)?)([KMGkmg])->(\d+(?:\.\d+)?)([KMGkmg])\((\d+(?:\.\d+)?)([KMGkmg])\)"#,
            options: []
        )
    }()

    private var minorStutterCount = 0
    private var criticalFreezeCount = 0
    private var maxPauseMs: Double = 0
    private var fullGCCount = 0
    private var allocationStallCount = 0
    private var outOfMemoryCount = 0
    private var lastUptimeSeconds: Double = 0
    private var heapOccupancies: [Double] = []
    private var tickDropCount = 0
    private var maxTickBehindMs = 0

    public init() {}

    public mutating func ingestGC(lines: [String]) {
        for line in lines {
            parseGCLine(line)
        }
    }

    public mutating func ingestGameLog(lines: [String]) {
        for line in lines {
            parseGameLogLine(line)
        }
    }

    public func snapshot() -> FreezeStats {
        let maxOccupancy = heapOccupancies.max() ?? 0.0
        let avgOccupancy = heapOccupancies.isEmpty
            ? 0.0
            : (heapOccupancies.reduce(0.0, +) / Double(heapOccupancies.count))

        return FreezeStats(
            minorStutterCount: minorStutterCount,
            criticalFreezeCount: criticalFreezeCount,
            maxPauseMs: maxPauseMs,
            fullGCCount: fullGCCount,
            allocationStallCount: allocationStallCount,
            outOfMemoryCount: outOfMemoryCount,
            lastUptimeSeconds: lastUptimeSeconds,
            maxHeapOccupancyRatio: maxOccupancy,
            averageHeapOccupancyRatio: avgOccupancy,
            tickDropCount: tickDropCount,
            maxTickBehindMs: maxTickBehindMs
        )
    }

    private mutating func parseGCLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Must contain Pause or Allocation Stall and end with <number>ms
        let isPause = trimmed.contains("Pause ")
        let isAllocationStall = trimmed.contains("Allocation Stall")
        guard isPause || isAllocationStall else { return }

        guard let durationMatch = Self.gcDurationRegex?.firstMatch(
            in: trimmed,
            options: [],
            range: NSRange(location: 0, length: (trimmed as NSString).length)
        ) else {
            return
        }

        let nsLine = trimmed as NSString
        let durationRange = durationMatch.range(at: 1)
        guard let duration = Double(nsLine.substring(with: durationRange)) else { return }

        // Extract uptime from first bracket: [12.345s]
        var uptime: Double? = nil
        if trimmed.hasPrefix("["), let closingBracket = trimmed.firstIndex(of: "]") {
            var rawUptime = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closingBracket])
            if rawUptime.hasSuffix("s") {
                rawUptime.removeLast()
            }
            uptime = Double(rawUptime)
        }

        if let uptime {
            lastUptimeSeconds = max(lastUptimeSeconds, uptime)
        }

        let isWarmup = (uptime ?? lastUptimeSeconds) < Self.warmupSeconds

        // Extract heap sizes A->B(C) if present
        if let heapMatch = Self.heapRegex?.firstMatch(
            in: trimmed,
            options: [],
            range: NSRange(location: 0, length: nsLine.length)
        ) {
            let bValStr = nsLine.substring(with: heapMatch.range(at: 3))
            let bUnit = nsLine.substring(with: heapMatch.range(at: 4)).uppercased()
            let cValStr = nsLine.substring(with: heapMatch.range(at: 5))
            let cUnit = nsLine.substring(with: heapMatch.range(at: 6)).uppercased()

            if let bVal = Double(bValStr), let cVal = Double(cValStr) {
                let bMB = convertToMB(value: bVal, unit: bUnit)
                let cMB = convertToMB(value: cVal, unit: cUnit)
                if cMB > 0 {
                    let ratio = bMB / cMB
                    if !isWarmup {
                        heapOccupancies.append(ratio)
                    }
                }
            }
        }

        if trimmed.contains("Pause Full") || trimmed.contains("Full GC") {
            if !isWarmup {
                fullGCCount += 1
            }
        }

        if isAllocationStall {
            if !isWarmup {
                allocationStallCount += 1
                criticalFreezeCount += 1
            }
            return
        }

        if !isWarmup {
            maxPauseMs = max(maxPauseMs, duration)
            if duration > 50.0 {
                criticalFreezeCount += 1
            } else if duration >= 15.0 {
                minorStutterCount += 1
            }
        }
    }

    private mutating func parseGameLogLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if trimmed.contains("OutOfMemoryError") {
            outOfMemoryCount += 1
            criticalFreezeCount += 1
            return
        }

        guard let match = Self.tickDropRegex?.firstMatch(
            in: trimmed,
            options: [],
            range: NSRange(location: 0, length: (trimmed as NSString).length)
        ) else {
            return
        }

        let nsLine = trimmed as NSString
        let msRange = match.range(at: 1)
        if msRange.location != NSNotFound {
            let msStr = nsLine.substring(with: msRange)
            if let ms = Int(msStr) {
                maxTickBehindMs = max(maxTickBehindMs, ms)
            }
        }
        tickDropCount += 1
    }

    private func convertToMB(value: Double, unit: String) -> Double {
        switch unit {
        case "K":
            return value / 1024.0
        case "G":
            return value * 1024.0
        default:
            return value
        }
    }

    // MARK: - File Tailing

    public static func readNewLines(of url: URL, fromOffset: inout UInt64) -> [String] {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return []
        }
        defer { try? handle.close() }

        guard let fileSize = try? handle.seekToEnd() else {
            return []
        }

        if fileSize < fromOffset {
            fromOffset = 0
        }

        guard fileSize > fromOffset else {
            return []
        }

        do {
            try handle.seek(toOffset: fromOffset)
        } catch {
            fromOffset = 0
            return []
        }

        let bytesToRead = Int(fileSize - fromOffset)
        let data = handle.readData(ofLength: bytesToRead)
        guard !data.isEmpty else { return [] }

        guard let lastNewlineIndex = data.lastIndex(of: 0x0A) else {
            return []
        }

        let completeData = data.subdata(in: 0..<(lastNewlineIndex + 1))
        fromOffset += UInt64(completeData.count)

        let text = String(decoding: completeData, as: UTF8.self)
        var lines = text.components(separatedBy: "\n")
        if lines.last?.isEmpty == true {
            lines.removeLast()
        }
        return lines
    }

    // MARK: - Environment Checks

    public static func javaArchitecture(of executable: URL) -> JavaArchitecture {
        #if os(macOS)
        let resolved = executable.resolvingSymlinksInPath()
        guard let handle = try? FileHandle(forReadingFrom: resolved) else {
            return .unknown
        }
        defer { try? handle.close() }

        let data = handle.readData(ofLength: 4096)
        guard data.count >= 8 else { return .unknown }

        var cpuTypes = Set<UInt32>()

        data.withUnsafeBytes { buffer in
            guard let ptr = buffer.bindMemory(to: UInt32.self).baseAddress else { return }
            let magic = ptr[0]

            let fatMagic: UInt32 = 0xCAFEBABE
            let fatCigam: UInt32 = 0xBEBAFECA
            let machO64LE: UInt32 = 0xFEEDFACF
            let machO64BE: UInt32 = 0xCFFAEDFE

            if magic == machO64LE {
                cpuTypes.insert(ptr[1])
            } else if magic == machO64BE {
                cpuTypes.insert(ptr[1].byteSwapped)
            } else if magic == fatMagic || magic == fatCigam {
                let isBE = (magic == fatMagic)
                let nfat = isBE ? ptr[1].byteSwapped : ptr[1]
                let maxArchs = min(Int(nfat), (data.count - 8) / 20)
                let bytePtr = buffer.baseAddress!.advanced(by: 8)
                for i in 0..<maxArchs {
                    let archPtr = bytePtr.advanced(by: i * 20).bindMemory(to: UInt32.self, capacity: 5)
                    let cputype = isBE ? archPtr[0].byteSwapped : archPtr[0]
                    cpuTypes.insert(cputype)
                }
            }
        }

        let arm64Type: UInt32 = 0x0100000C
        let x86_64Type: UInt32 = 0x01000007

        #if arch(arm64)
        if cpuTypes.contains(arm64Type) {
            return .arm64Native
        } else if cpuTypes.contains(x86_64Type) {
            return .rosetta
        } else {
            return .unknown
        }
        #else
        if cpuTypes.contains(x86_64Type) {
            return .x86_64Native
        } else {
            return .unknown
        }
        #endif
        #else
        return .unknown
        #endif
    }

    public static func voxyWithHighRenderDistance(modsDirectory: URL, optionsFile: URL) -> Bool {
        guard MinecraftOptionsPatcher.hasEnabledVoxy(modsDirectory: modsDirectory) else {
            return false
        }
        guard let content = try? String(contentsOf: optionsFile, encoding: .utf8) else {
            return false
        }
        for line in content.components(separatedBy: "\n") {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            if key == "renderDistance" {
                let valStr = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                if let rd = Int(valStr), rd > 8 {
                    return true
                }
            }
        }
        return false
    }
}
