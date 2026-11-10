import Foundation

/// Shares one in-flight operation between callers that arrive at the same moment: the first starts it, the others
/// wait for its result. Token refresh needs this: two parallel requests with one refresh token can lose the session.
public actor SingleFlight<Value: Sendable> {
    private var inFlight: Task<Value, Error>?

    public init() {}

    public func run(_ work: @escaping @Sendable () async throws -> Value) async throws -> Value {
        if let inFlight { return try await inFlight.value }
        let task = Task { try await work() }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }
}
