import Foundation
import Testing
@testable import LauncherCore

struct ServerCommandsTests {
    @Test func testHealValidName() {
        #expect(ServerCommand.heal("Mossy") == "effect give Mossy minecraft:instant_health 1 10")
    }

    @Test func testHealInvalidNames() {
        #expect(ServerCommand.heal("Moss y") == nil)
        #expect(ServerCommand.heal("Moss;rm -rf") == nil)
        #expect(ServerCommand.heal("Moss\ny") == nil)
        #expect(ServerCommand.heal("") == nil)
        #expect(ServerCommand.heal(String(repeating: "a", count: 17)) == nil)
    }

    @Test func testHealAndFeed() {
        let commands = ServerCommand.healAndFeed("Mossy")
        #expect(commands == [
            "effect give Mossy minecraft:instant_health 1 10",
            "effect give Mossy minecraft:saturation 1 20"
        ])
    }

    @Test func testHealAndFeedInvalidName() {
        #expect(ServerCommand.healAndFeed("Moss y") == nil)
    }

    @Test func testGamemodeValid() {
        #expect(ServerCommand.gamemode("creative", "Mossy") == "gamemode creative Mossy")
    }

    @Test func testGamemodeInvalidMode() {
        #expect(ServerCommand.gamemode("god", "Mossy") == nil)
    }

    @Test func testGamemodeInvalidName() {
        #expect(ServerCommand.gamemode("creative", "Moss;y") == nil)
    }

    @Test func testKickStripsNewlinesInReason() {
        #expect(ServerCommand.kick("Mossy", reason: "bad\nactor") == "kick Mossy bad actor")
    }

    @Test func testKickNoReason() {
        #expect(ServerCommand.kick("Mossy", reason: nil) == "kick Mossy")
    }

    @Test func testKickInvalidName() {
        #expect(ServerCommand.kick("Moss y", reason: "x") == nil)
    }

    @Test func testOpDeopOpPardon() {
        #expect(ServerCommand.op("Mossy") == "op Mossy")
        #expect(ServerCommand.deop("Mossy") == "deop Mossy")
        #expect(ServerCommand.ban("Mossy", reason: nil) == "ban Mossy")
        #expect(ServerCommand.pardon("Mossy") == "pardon Mossy")
    }

    @Test func testSetMaxHealthModernVersion() {
        let command = ServerCommand.setMaxHealth(40, "Mossy", minecraftVersion: "1.21.2")
        #expect(command == "attribute Mossy minecraft:max_health base set 40")
    }

    @Test func testSetMaxHealthModernVersionLaterPatch() {
        let command = ServerCommand.setMaxHealth(40, "Mossy", minecraftVersion: "1.21.4")
        #expect(command == "attribute Mossy minecraft:max_health base set 40")
    }

    @Test func testSetMaxHealthLegacyVersion() {
        let command = ServerCommand.setMaxHealth(40, "Mossy", minecraftVersion: "1.21.1")
        #expect(command == "attribute Mossy minecraft:generic.max_health base set 40")
    }

    @Test func testSetMaxHealthOlderVersion() {
        let command = ServerCommand.setMaxHealth(40, "Mossy", minecraftVersion: "1.20.1")
        #expect(command == "attribute Mossy minecraft:generic.max_health base set 40")
    }

    @Test func testSetMaxHealthClampsValue() {
        let low = ServerCommand.setMaxHealth(-5, "Mossy", minecraftVersion: "1.21.2")
        let high = ServerCommand.setMaxHealth(5000, "Mossy", minecraftVersion: "1.21.2")
        #expect(low == "attribute Mossy minecraft:max_health base set 1")
        #expect(high == "attribute Mossy minecraft:max_health base set 1024")
    }

    @Test func testSetMaxHealthInvalidName() {
        #expect(ServerCommand.setMaxHealth(20, "Moss y", minecraftVersion: "1.21.2") == nil)
    }

    @Test func testDifficultyValidAndInvalid() {
        #expect(ServerCommand.difficulty("hard") == "difficulty hard")
        #expect(ServerCommand.difficulty("nightmare") == nil)
    }

    @Test func testGamerulesWhitelist() {
        #expect(ServerCommand.gamerule("keepInventory", true) == "gamerule keepInventory true")
        #expect(ServerCommand.gamerule("mobGriefing", false) == "gamerule mobGriefing false")
        #expect(ServerCommand.gamerule("doDaylightCycle", true) == "gamerule doDaylightCycle true")
        #expect(ServerCommand.gamerule("doMobSpawning", false) == "gamerule doMobSpawning false")
        #expect(ServerCommand.gamerule("doFireTick", true) == "gamerule doFireTick true")
        #expect(ServerCommand.gamerule("naturalRegeneration", false) == "gamerule naturalRegeneration false")
    }

    @Test func testGamerulesRejectUnknownName() {
        #expect(ServerCommand.gamerule("randomTickSpeed", true) == nil)
    }

    @Test func testTimeAndWeather() {
        #expect(ServerCommand.time("noon") == "time set noon")
        #expect(ServerCommand.time("evening") == nil)
        #expect(ServerCommand.weather("thunder") == "weather thunder")
        #expect(ServerCommand.weather("snow") == nil)
    }

    @Test func testSaveAll() {
        #expect(ServerCommand.saveAll() == "save-all")
    }

    @Test func testLogParserJoinedWithPrefix() {
        let event = ServerLogParser.parse("[17:03:40] [Server thread/INFO]: Mossy joined the game")
        #expect(event == .joined("Mossy"))
    }

    @Test func testLogParserLeftWithPrefix() {
        let event = ServerLogParser.parse("[17:03:40] [Server thread/INFO]: Mossy left the game")
        #expect(event == .left("Mossy"))
    }

    @Test func testLogParserChatWithPrefix() {
        let event = ServerLogParser.parse("[17:03:40] [Server thread/INFO]: <Mossy> hello")
        #expect(event == .chat(player: "Mossy", message: "hello"))
    }

    @Test func testLogParserWithoutPrefix() {
        let event = ServerLogParser.parse("Mossy joined the game")
        #expect(event == .joined("Mossy"))
    }

    @Test func testLogParserOther() {
        let event = ServerLogParser.parse("[17:03:40] [Server thread/INFO]: Starting minecraft server")
        #expect(event == .other("Starting minecraft server"))
    }

    @Test func testPlayerTrackerJoinLeaveReset() {
        var tracker = ServerPlayerTracker()
        tracker.apply("[17:03:40] [Server thread/INFO]: Mossy joined the game")
        tracker.apply("[17:03:41] [Server thread/INFO]: Alice joined the game")
        #expect(tracker.online == ["Alice", "Mossy"])

        tracker.apply("[17:03:42] [Server thread/INFO]: Mossy left the game")
        #expect(tracker.online == ["Alice"])

        tracker.reset()
        #expect(tracker.online == [])
    }

    @Test func testPlayerTrackerIgnoresDuplicateJoins() {
        var tracker = ServerPlayerTracker()
        tracker.apply("Mossy joined the game")
        tracker.apply("Mossy joined the game")
        #expect(tracker.online == ["Mossy"])
    }
}
