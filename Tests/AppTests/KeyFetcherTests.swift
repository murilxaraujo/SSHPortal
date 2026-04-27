import Testing
import Foundation
@testable import App

@Suite struct KeyFetcherTests {
    @Test func parsesMultipleKeysFromBody() async throws {
        let body = """
        ssh-ed25519 AAAA host1
        ssh-rsa BBBB host2

        sk-ssh-ed25519@openssh.com CCCC yk
        """
        let fetcher = StubFetcher(source: .github, body: body)
        let keys = try await fetcher.fetch(username: "anyone")
        #expect(keys.count == 3)
        #expect(keys[0].type == .ed25519)
        #expect(keys[1].type == .rsa)
        #expect(keys[2].type == .ed25519SK)
        #expect(keys.allSatisfy { $0.source == .github })
    }

    @Test func skipsMalformedLines() async throws {
        let body = "ssh-ed25519 AAAA ok\nnonsense line\n"
        let fetcher = StubFetcher(source: .gitlab, body: body)
        let keys = try await fetcher.fetch(username: "anyone")
        #expect(keys.count == 1)
        #expect(keys[0].source == .gitlab)
    }

    @Test func emptyBodyReturnsEmpty() async throws {
        let fetcher = StubFetcher(source: .github, body: "")
        let keys = try await fetcher.fetch(username: "anyone")
        #expect(keys.isEmpty)
    }
}
