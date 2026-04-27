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

    @Test func refreshOnceCallsLoader() async throws {
        let file = try KeysFile.parse("title: t\nsources:\n  manual:\n    - key: \"ssh-ed25519 AAAA m\"")
        let loader = KeyLoader(
            file: file,
            github: StubFetcher(source: .github, body: ""),
            gitlab: StubFetcher(source: .gitlab, body: "")
        )
        let store = KeyStore.empty()
        await store.refreshOnce(using: loader)
        let keys = await store.all()
        #expect(keys.count == 1)
        #expect(await store.lastRefresh != nil)
    }

    @Test func loaderMergesManualAndRemote() async throws {
        let yaml = """
        title: t
        sources:
          github:
            - alice
          gitlab: []
          manual:
            - comment: Local
              key: "ssh-ed25519 LOCALKEY local@host"
        """
        let file = try KeysFile.parse(yaml)
        let stubGH = StubFetcher(source: .github, body: "ssh-ed25519 GHKEY alice@gh\nssh-rsa GHRSA alice@gh\n")
        let stubGL = StubFetcher(source: .gitlab, body: "")
        let loader = KeyLoader(file: file, github: stubGH, gitlab: stubGL)
        let keys = try await loader.loadAll()
        #expect(keys.count == 3)
        #expect(keys.contains { $0.publicKey.contains("LOCALKEY") })
        #expect(keys.contains { $0.publicKey.contains("GHKEY") })
    }
}
