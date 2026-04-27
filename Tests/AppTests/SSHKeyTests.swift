import Testing
import Foundation
@testable import App

@Suite struct SSHKeyTests {
    @Test func parsesEd25519() throws {
        let line = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleData murilo@laptop"
        let key = try SSHKey.parse(line, source: .manual)
        #expect(key.type == .ed25519)
        #expect(key.comment == "murilo@laptop")
        #expect(key.publicKey == line)
    }

    @Test func parsesRSA() throws {
        let key = try SSHKey.parse("ssh-rsa AAAAB3NzaC1yc2E key@host", source: .github)
        #expect(key.type == .rsa)
        #expect(key.source == .github)
    }

    @Test func parsesEcdsa() throws {
        let key = try SSHKey.parse("ecdsa-sha2-nistp256 AAAA key@host", source: .manual)
        #expect(key.type == .ecdsa)
    }

    @Test func parsesEcdsaSK() throws {
        let key = try SSHKey.parse("sk-ecdsa-sha2-nistp256@openssh.com AAAAInN key@yk", source: .manual)
        #expect(key.type == .ecdsaSK)
    }

    @Test func parsesEd25519SK() throws {
        let key = try SSHKey.parse("sk-ssh-ed25519@openssh.com AAAA key@yk", source: .manual)
        #expect(key.type == .ed25519SK)
    }

    @Test func rejectsEmpty() {
        #expect(throws: SSHKey.ParseError.self) {
            _ = try SSHKey.parse("", source: .manual)
        }
    }

    @Test func rejectsUnknownPrefix() {
        #expect(throws: SSHKey.ParseError.self) {
            _ = try SSHKey.parse("nonsense AAAA host", source: .manual)
        }
    }

    @Test func rejectsMissingBlob() {
        #expect(throws: SSHKey.ParseError.self) {
            _ = try SSHKey.parse("ssh-ed25519", source: .manual)
        }
    }

    @Test func fingerprintIsStable() throws {
        let a = try SSHKey.parse("ssh-ed25519 AAAA host", source: .github)
        let b = try SSHKey.parse("ssh-ed25519 AAAA other-host", source: .gitlab)
        #expect(a.fingerprint == b.fingerprint)
        #expect(a.fingerprint.hasPrefix("SHA256:"))
    }

    @Test func fingerprintDiffersForDifferentBlobs() throws {
        let a = try SSHKey.parse("ssh-ed25519 AAAA host", source: .manual)
        let b = try SSHKey.parse("ssh-ed25519 BBBB host", source: .manual)
        #expect(a.fingerprint != b.fingerprint)
    }
}
