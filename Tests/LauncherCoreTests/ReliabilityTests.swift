import Foundation
import Testing
@testable import LauncherCore

private actor Counter {
    private var value = 0

    func increment() -> Int {
        value += 1
        return value
    }

    func current() -> Int {
        value
    }
}

struct ReliabilityTests {
    @Test func singleFlightCoalescesConcurrentCallers() async throws {
        let counter = Counter()
        let flight = SingleFlight<Int>()

        let results = try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    try await flight.run {
                        _ = await counter.increment()
                        try await Task.sleep(nanoseconds: 50_000_000)
                        return 7
                    }
                }
            }
            var collected: [Int] = []
            for try await value in group {
                collected.append(value)
            }
            return collected
        }

        #expect(results.count == 20)
        #expect(results.allSatisfy { $0 == 7 })
        let runs = await counter.current()
        #expect(runs == 1)
    }

    @Test func singleFlightRunsAgainAfterCompletion() async throws {
        let counter = Counter()
        let flight = SingleFlight<Int>()

        let first = try await flight.run {
            _ = await counter.increment()
            return 7
        }
        #expect(first == 7)

        let second = try await flight.run {
            _ = await counter.increment()
            return 7
        }
        #expect(second == 7)

        let runs = await counter.current()
        #expect(runs == 2)
    }

    @Test func singleFlightPropagatesErrorToAllCallersThenRecovers() async throws {
        struct TestError: Error {}
        let counter = Counter()
        let flight = SingleFlight<Int>()

        let results = await withTaskGroup(of: Result<Int, Error>.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    do {
                        let value = try await flight.run {
                            _ = await counter.increment()
                            try await Task.sleep(nanoseconds: 50_000_000)
                            throw TestError()
                        }
                        return .success(value)
                    } catch {
                        return .failure(error)
                    }
                }
            }
            var collected: [Result<Int, Error>] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        #expect(results.count == 20)
        #expect(results.allSatisfy { result in
            if case .failure = result { return true }
            return false
        })
        let runsAfterFailure = await counter.current()
        #expect(runsAfterFailure == 1)

        let recovered = try await flight.run {
            _ = await counter.increment()
            return 7
        }
        #expect(recovered == 7)
        let totalRuns = await counter.current()
        #expect(totalRuns == 2)
    }

    @Test func safeJSONReadMissingFileGivesNilAndNoCorruptFile() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let url = dir.appendingPathComponent("missing.json")
        let result = SafeJSON.read([String].self, from: url)
        #expect(result == nil)

        let corruptURL = url.appendingPathExtension("corrupt")
        #expect(!FileManager.default.fileExists(atPath: corruptURL.path))
    }

    @Test func safeJSONReadValidFileDecodes() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let url = dir.appendingPathComponent("valid.json")
        let value = ["a", "b"]
        let data = try JSONEncoder().encode(value)
        try data.write(to: url)

        let result = SafeJSON.read([String].self, from: url)
        #expect(result == value)
    }

    @Test func safeJSONReadBrokenFileGivesNilAndPreservesCorruptCopy() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let url = dir.appendingPathComponent("broken.json")
        let brokenData = Data("{ not valid json".utf8)
        try brokenData.write(to: url)

        let result = SafeJSON.read([String].self, from: url)
        #expect(result == nil)

        let corruptURL = url.appendingPathExtension("corrupt")
        #expect(FileManager.default.fileExists(atPath: corruptURL.path))
        let corruptData = try Data(contentsOf: corruptURL)
        #expect(corruptData == brokenData)

        #expect(FileManager.default.fileExists(atPath: url.path))
        let originalData = try Data(contentsOf: url)
        #expect(originalData == brokenData)
    }

    @Test func emberAuthErrorEndsSessionForCredentialAndAuthFailures() {
        #expect(EmberAuthError.invalidCredentials.endsSession)
        #expect(EmberAuthError.http(400, "").endsSession)
        #expect(EmberAuthError.http(401, "").endsSession)
        #expect(EmberAuthError.http(403, "").endsSession)
    }

    @Test func emberAuthErrorDoesNotEndSessionForTransientFailures() {
        #expect(!EmberAuthError.http(500, "").endsSession)
        #expect(!EmberAuthError.http(429, "").endsSession)
        #expect(!EmberAuthError.rateLimited.endsSession)
        #expect(!EmberAuthError.cancelled.endsSession)
        #expect(!EmberAuthError.invalidResponse.endsSession)
    }

    @Test func emberLobbiesDecodeJoinRecognizesRateLimited() throws {
        let json = Data("""
        [ { "result": "rate_limited", "lobby": null } ]
        """.utf8)
        let outcome = try EmberLobbies.decodeJoin(json)
        #expect(outcome == .rateLimited)
    }
}
