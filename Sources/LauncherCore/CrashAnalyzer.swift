import Foundation

public enum CrashKind: String, Sendable, CaseIterable {
    case outOfMemory
    case wrongJavaVersion
    case badJavaArguments
    case missingDependency
    case modConflict
    case brokenMod
    case graphicsDriver
    case jvmCrash
    case unknown
}

public struct CrashDiagnosis: Sendable, Equatable {
    public var kind: CrashKind
    public var culprit: String?
    public var detail: String
    public var excerpt: String
    public var reportFile: URL?

    public init(
        kind: CrashKind,
        culprit: String? = nil,
        detail: String,
        excerpt: String,
        reportFile: URL? = nil
    ) {
        self.kind = kind
        self.culprit = culprit
        self.detail = detail
        self.excerpt = excerpt
        self.reportFile = reportFile
    }
}

public enum CrashAnalyzer {
    public static func analyze(log: String, crashReport: String?, reportFile: URL?, exitCode: Int32) -> CrashDiagnosis {
        let combined = (crashReport ?? "") + "\n" + log
        let lines = combined.components(separatedBy: "\n")

        // Rule 1: Out of Memory
        if let idx = lines.firstIndex(where: { $0.contains("java.lang.OutOfMemoryError") }) {
            return CrashDiagnosis(
                kind: .outOfMemory,
                culprit: nil,
                detail: lines[idx].trimmingCharacters(in: .whitespaces),
                excerpt: makeExcerpt(lines: lines, index: idx),
                reportFile: reportFile
            )
        }

        // Rule 2: Wrong Java Version
        if let idx = lines.firstIndex(where: {
            $0.contains("UnsupportedClassVersionError") ||
            $0.contains("compiled by a more recent version of the Java Runtime")
        }) {
            return CrashDiagnosis(
                kind: .wrongJavaVersion,
                culprit: nil,
                detail: lines[idx].trimmingCharacters(in: .whitespaces),
                excerpt: makeExcerpt(lines: lines, index: idx),
                reportFile: reportFile
            )
        }

        // Bad Java arguments
        if let idx = lines.firstIndex(where: {
            $0.contains("Error occurred during initialization of VM") ||
            $0.contains("Unrecognized VM option") ||
            $0.contains("Invalid maximum heap size") ||
            $0.contains("Invalid initial heap size") ||
            $0.contains("Could not create the Java Virtual Machine") ||
            $0.contains("Could not reserve enough space")
        }) {
            let detail: String
            if let initVmIdx = lines.firstIndex(where: { $0.contains("Error occurred during initialization of VM") }),
               let nextNonEmpty = lines[(initVmIdx + 1)...].first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                detail = nextNonEmpty.trimmingCharacters(in: .whitespaces)
            } else {
                detail = lines[idx].trimmingCharacters(in: .whitespaces)
            }
            return CrashDiagnosis(
                kind: .badJavaArguments,
                culprit: nil,
                detail: detail,
                excerpt: makeExcerpt(lines: lines, index: idx),
                reportFile: reportFile
            )
        }

        // Rule 3: Fabric Loader dependency errors & mod conflicts
        if let match = findFabricDependencyOrConflict(lines: lines) {
            return CrashDiagnosis(
                kind: match.kind,
                culprit: match.culprit,
                detail: match.detail,
                excerpt: makeExcerpt(lines: lines, index: match.index),
                reportFile: reportFile
            )
        }

        // Rule 4: Mixin failures
        if let idx = lines.firstIndex(where: { line in
            line.contains("Mixin apply for mod") ||
            line.contains("InvalidMixinException") ||
            line.contains("MixinApplyError") ||
            line.contains("Mixin transformation of")
        }) {
            let line = lines[idx]
            var culprit = extractMixinCulprit(from: line)
            if culprit == nil {
                let start = max(0, idx - 2)
                let end = min(lines.count - 1, idx + 2)
                for nearby in lines[start...end] {
                    if let found = extractMixinCulprit(from: nearby) {
                        culprit = found
                        break
                    }
                }
            }
            return CrashDiagnosis(
                kind: .brokenMod,
                culprit: culprit,
                detail: line.trimmingCharacters(in: .whitespaces),
                excerpt: makeExcerpt(lines: lines, index: idx),
                reportFile: reportFile
            )
        }

        // Rule 5: Suspected Mods section
        if let headerIdx = lines.firstIndex(where: { $0.contains("Suspected Mods:") }) {
            for idx in (headerIdx + 1)..<lines.count {
                var raw = lines[idx].trimmingCharacters(in: .whitespaces)
                if raw.isEmpty { continue }
                if raw.hasPrefix("--") || raw.hasPrefix("Thread") || raw.hasPrefix("Stacktrace:") {
                    break
                }
                while raw.hasPrefix("-") || raw.hasPrefix("•") || raw.hasPrefix("*") || raw.hasPrefix("\t") {
                    raw = raw.dropFirst().trimmingCharacters(in: .whitespaces)
                }
                if raw.lowercased() == "none" { continue }

                let name: String
                if let paren = raw.firstIndex(of: "(") {
                    name = String(raw[..<paren]).trimmingCharacters(in: .whitespaces)
                } else if let comma = raw.firstIndex(of: ",") {
                    name = String(raw[..<comma]).trimmingCharacters(in: .whitespaces)
                } else {
                    name = raw
                }

                let lower = name.lowercased()
                if lower == "minecraft" || lower == "java" || lower.contains("fabric loader") || lower.isEmpty {
                    continue
                }

                return CrashDiagnosis(
                    kind: .brokenMod,
                    culprit: name,
                    detail: "Suspected mod: \(raw)",
                    excerpt: makeExcerpt(lines: lines, index: idx),
                    reportFile: reportFile
                )
            }
        }

        // Rule 6: Graphics driver
        if let idx = lines.firstIndex(where: { line in
            let lower = line.lowercased()
            return line.contains("GLFW error") ||
                line.contains("Pixel format not accelerated") ||
                line.contains("Failed to create window") ||
                (lower.contains("opengl") && lower.contains("error"))
        }) {
            return CrashDiagnosis(
                kind: .graphicsDriver,
                culprit: nil,
                detail: lines[idx].trimmingCharacters(in: .whitespaces),
                excerpt: makeExcerpt(lines: lines, index: idx),
                reportFile: reportFile
            )
        }

        // Rule 7: JVM crash
        let isHsErr = reportFile?.lastPathComponent.hasPrefix("hs_err") == true
        let jvmCrashIdx = lines.firstIndex(where: {
            $0.contains("A fatal error has been detected by the Java Runtime Environment") ||
            $0.contains("SIGSEGV") ||
            $0.contains("SIGBUS")
        })

        if isHsErr || jvmCrashIdx != nil {
            var problematicFrame: String?
            var frameIdx: Int?
            for (i, line) in lines.enumerated() {
                if line.contains("Problematic frame:") {
                    var trimmed = line.trimmingCharacters(in: .whitespaces)
                    while trimmed.hasPrefix("#") {
                        trimmed = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                    }
                    // The frame itself is on the next "# " line of an hs_err file.
                    if trimmed.isEmpty || trimmed.hasSuffix(":"), i + 1 < lines.count {
                        var next = lines[i + 1].trimmingCharacters(in: .whitespaces)
                        while next.hasPrefix("#") {
                            next = next.dropFirst().trimmingCharacters(in: .whitespaces)
                        }
                        trimmed = next
                    }
                    problematicFrame = trimmed.isEmpty ? nil : trimmed
                    frameIdx = i
                    break
                }
            }

            let detail: String
            if let frame = problematicFrame {
                let frameText = frame.hasSuffix(".") ? frame : "\(frame)."
                detail = "A fatal JVM crash occurred. \(frameText)"
            } else {
                detail = "A fatal error has been detected by the Java Runtime Environment."
            }

            let targetIdx = frameIdx ?? jvmCrashIdx ?? 0
            return CrashDiagnosis(
                kind: .jvmCrash,
                culprit: nil,
                detail: detail,
                excerpt: makeExcerpt(lines: lines, index: targetIdx),
                reportFile: reportFile
            )
        }

        // Rule 8: Unknown
        let detail: String
        if let causedBy = lines.last(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("Caused by:") }) {
            detail = causedBy.trimmingCharacters(in: .whitespaces)
        } else if let exc = lines.last(where: { $0.contains("Exception") || $0.contains("Error") }) {
            detail = exc.trimmingCharacters(in: .whitespaces)
        } else {
            detail = "The game exited with code \(exitCode)."
        }

        let logLines = log.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let excerpt = logLines.suffix(12).joined(separator: "\n")

        return CrashDiagnosis(
            kind: .unknown,
            culprit: nil,
            detail: detail,
            excerpt: excerpt,
            reportFile: reportFile
        )
    }

    private static func findFabricDependencyOrConflict(lines: [String]) -> (kind: CrashKind, culprit: String?, detail: String, index: Int)? {
        var searchIndices = Array(0..<lines.count)
        if let headerIdx = lines.firstIndex(where: { $0.contains("Incompatible mod set!") }) {
            let nearby = Array((headerIdx + 1)..<min(lines.count, headerIdx + 40))
            let remaining = searchIndices.filter { !nearby.contains($0) }
            searchIndices = nearby + remaining
        }

        for idx in searchIndices {
            let line = lines[idx]
            let lower = line.lowercased()

            let isMissing = lower.contains("requires") && lower.contains("missing")
            let hasModSentence = lower.contains("mod '") || lower.contains("mod (") || line.contains("Mod ")
            let isConflict = hasModSentence && (lower.contains("conflicts with") || lower.contains("breaks") || lower.contains("is incompatible with"))

            if isMissing || isConflict {
                var detail = line.trimmingCharacters(in: .whitespaces)
                while detail.hasPrefix("-") || detail.hasPrefix("•") || detail.hasPrefix("*") {
                    detail = detail.dropFirst().trimmingCharacters(in: .whitespaces)
                }
                let culprit = extractFabricCulprit(from: line)
                return (isMissing ? .missingDependency : .modConflict, culprit, detail, idx)
            }
        }

        return nil
    }

    private static func extractFabricCulprit(from line: String) -> String? {
        if let startQuote = line.range(of: "Mod '", options: .caseInsensitive) {
            let after = line[startQuote.upperBound...]
            if let endQuote = after.firstIndex(of: "'") {
                let name = String(after[..<endQuote]).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    return name
                }
            }
        }

        if let modRange = line.range(of: "mod", options: .caseInsensitive) {
            let after = line[modRange.upperBound...]
            if let openParen = after.firstIndex(of: "("),
               let closeParen = after[openParen...].firstIndex(of: ")") {
                let id = String(after[after.index(after: openParen)..<closeParen]).trimmingCharacters(in: .whitespaces)
                if !id.isEmpty {
                    return id
                }
            }
        }

        return nil
    }

    private static func extractMixinCulprit(from line: String) -> String? {
        guard let range = line.range(of: "mod ", options: .caseInsensitive) else {
            return nil
        }
        var remainder = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
        if remainder.hasPrefix("<") || remainder.hasPrefix("'") || remainder.hasPrefix("\"") {
            remainder = String(remainder.dropFirst())
        }
        let stopChars = CharacterSet(charactersIn: " >'\":,;\t\n()")
        let parts = remainder.components(separatedBy: stopChars)
        if let first = parts.first, !first.isEmpty {
            return first
        }
        return nil
    }

    private static func makeExcerpt(lines: [String], index: Int) -> String {
        let start = max(0, index - 2)
        let end = min(lines.count - 1, index + 2)
        let selected = lines[start...end]
        return selected.prefix(12).joined(separator: "\n")
    }
}
