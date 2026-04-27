import Testing
import Foundation
@testable import App

@Suite struct KeyStoreTests {
    private func ed(_ blob: String, _ source: KeySource, _ comment: String? = nil) -> SSHKey {
        let line = "ssh-ed25519 \(blob)" + (comment.map { " \($0)" } ?? "")
        return try! SSHKey.parse(line, source: source)
    }

    @Test func dedupesByFingerprintWithManualWinning() async {
        let m = ed("AAAA", .manual, "manual-key")
        let g = ed("AAAA", .github, "github-key")
        let store = KeyStore.empty()
        await store.replaceAll([g, m])
        let result = await store.all()
        #expect(result.count == 1)
        #expect(result[0].source == .manual)
        #expect(result[0].comment == "manual-key")
    }

    @Test func dedupePrioritizesGithubOverGitlab() async {
        let g = ed("BBBB", .github, "gh")
        let l = ed("BBBB", .gitlab, "gl")
        let store = KeyStore.empty()
        await store.replaceAll([l, g])
        let result = await store.all()
        #expect(result.count == 1)
        #expect(result[0].source == .github)
    }

    @Test func filteredByType() async throws {
        let a = try SSHKey.parse("ssh-ed25519 AAAA a", source: .manual)
        let b = try SSHKey.parse("ssh-rsa BBBB b", source: .manual)
        let store = KeyStore.empty()
        await store.replaceAll([a, b])
        let edKeys = await store.filtered(by: .ed25519)
        #expect(edKeys.count == 1)
        #expect(edKeys[0].type == .ed25519)
    }

    @Test func sortedByPriorityThenType() async throws {
        let m1 = try SSHKey.parse("ssh-rsa MMMM m-rsa", source: .manual)
        let m2 = try SSHKey.parse("ssh-ed25519 NNNN m-ed", source: .manual)
        let g1 = try SSHKey.parse("ssh-ed25519 GGGG g-ed", source: .github)
        let store = KeyStore.empty()
        await store.replaceAll([g1, m1, m2])
        let result = await store.all()
        #expect(result.count == 3)
        #expect(result[0].source == .manual)
        #expect(result[1].source == .manual)
        #expect(result[2].source == .github)
    }
}
