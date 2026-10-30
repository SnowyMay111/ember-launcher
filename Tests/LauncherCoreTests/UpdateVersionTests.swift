import Testing
@testable import LauncherCore

struct UpdateVersionTests {
    @Test func vPrefixIsIgnored() {
        #expect(UpdateVersion.compare("v1.2.3", "1.2.3") == .orderedSame)
    }

    @Test func minorVersionIsNewer() {
        #expect(UpdateVersion.isNewer("0.10.0", than: "0.9.0"))
    }

    @Test func suffixIsIgnoredInComparison() {
        #expect(UpdateVersion.compare("1.2.0-beta", "1.2.0") == .orderedSame)
    }

    @Test func differentLengthsCanBeEqual() {
        #expect(UpdateVersion.compare("1.2", "1.2.0") == .orderedSame)
    }

    @Test func isNewerIsFalseWhenSame() {
        #expect(!UpdateVersion.isNewer("1.2.0", than: "1.2.0"))
    }

    @Test func isNewerIsFalseWhenOlder() {
        #expect(!UpdateVersion.isNewer("0.9.0", than: "0.10.0"))
    }
}
