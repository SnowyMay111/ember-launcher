import Testing
@testable import LauncherCore

@Suite struct ServerActivityTests {
    @Test func feedIsNewestFirstAndIgnoresNoise() {
        let lines = [
            "[17:03:00] [Server thread/INFO]: Done (4.2s)! For help, type \"help\"",
            "[17:03:40] [Server thread/INFO]: Mossy joined the game",
            "[17:03:41] [Server thread/INFO]: <Mossy> hi",
            "[17:04:00] [Server thread/INFO]: Saved the game",
            "[17:05:00] [Server thread/INFO]: Mossy left the game",
        ]
        let feed = ServerActivityFeed.build(from: lines)
        #expect(feed == [.left("Mossy"), .worldSaved, .joined("Mossy"), .started])
    }

    @Test func feedKeepsOnlyTheLatest() {
        let lines = (0..<20).map { "Player\($0) joined the game" }
        let feed = ServerActivityFeed.build(from: lines, limit: 3)
        #expect(feed == [.joined("Player19"), .joined("Player18"), .joined("Player17")])
    }
}
