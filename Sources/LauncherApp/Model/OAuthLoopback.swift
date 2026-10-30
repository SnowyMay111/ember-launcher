import Foundation
import Network

/// Catches the browser redirect of an OAuth sign-in on 127.0.0.1 and hands back the `code` query value.
/// The port must be on Supabase's redirect allow-list (see docs/supabase/schema.sql).
enum OAuthLoopback {
    static let port: UInt16 = 54545
    static var redirectURL: URL { URL(string: "http://127.0.0.1:\(port)/callback")! }

    enum Failure: Error, LocalizedError {
        case portBusy, timedOut, denied(String)

        var errorDescription: String? {
            switch self {
            case .portBusy: return L("Another sign-in is already waiting. Close it and try again.")
            case .timedOut: return L("Sign-in timed out.")
            case .denied(let message): return message
            }
        }
    }

    static func waitForCode(timeout: TimeInterval = 180) async throws -> String {
        let waiter = Waiter()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiter.start(port: port, timeout: timeout, continuation: continuation)
            }
        } onCancel: {
            waiter.finish(.failure(CancellationError()))
        }
    }

    private final class Waiter: @unchecked Sendable {
        private let queue = DispatchQueue(label: "ember.oauth.loopback")
        private var listener: NWListener?
        private var continuation: CheckedContinuation<String, Error>?
        private var finished = false

        func start(port: UInt16, timeout: TimeInterval, continuation: CheckedContinuation<String, Error>) {
            queue.async {
                self.continuation = continuation
                let parameters = NWParameters.tcp
                parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port) ?? 54545)
                guard let listener = try? NWListener(using: parameters) else {
                    self.finish(.failure(Failure.portBusy))
                    return
                }
                self.listener = listener
                listener.stateUpdateHandler = { state in
                    if case .failed = state { self.finish(.failure(Failure.portBusy)) }
                }
                listener.newConnectionHandler = { connection in self.handle(connection) }
                listener.start(queue: self.queue)
                self.queue.asyncAfter(deadline: .now() + timeout) { self.finish(.failure(Failure.timedOut)) }
            }
        }

        func finish(_ result: Result<String, Error>) {
            queue.async {
                guard !self.finished else { return }
                self.finished = true
                self.listener?.cancel()
                self.listener = nil
                let pending = self.continuation
                self.continuation = nil
                pending?.resume(with: result)
            }
        }

        private func handle(_ connection: NWConnection) {
            connection.start(queue: queue)
            connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, _ in
                let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                let items = Self.queryItems(of: request)
                let code = items["code"]
                let error = items["error_description"] ?? items["error"]
                let message = code != nil ? L("You are signed in. You can return to Ember.") : L("Sign-in failed. You can close this tab.")
                let body = "<!doctype html><meta charset=utf-8><title>Ember</title><body style=\"font-family:-apple-system,sans-serif;background:#0d0c0c;color:#eee;display:grid;place-items:center;height:100vh\"><p>\(message)</p></body>"
                let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
                connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
                if let code {
                    self.finish(.success(code))
                } else if let error {
                    self.finish(.failure(Failure.denied(error)))
                }
            }
        }

        /// Query items of the first request line, e.g. `GET /callback?code=abc HTTP/1.1`.
        private static func queryItems(of request: String) -> [String: String] {
            guard let line = request.split(separator: "\r\n").first else { return [:] }
            let parts = line.split(separator: " ")
            guard parts.count >= 2, let components = URLComponents(string: "http://127.0.0.1" + parts[1]) else { return [:] }
            var result: [String: String] = [:]
            for item in components.queryItems ?? [] { result[item.name] = item.value ?? "" }
            return result
        }
    }
}
