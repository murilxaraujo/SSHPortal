import Foundation
import Crypto

/// The wire-format prefix that distinguishes one SSH public key family from another.
///
/// Used both for grouping in the UI and for filtering on `GET /keys/:type`.
/// The raw values match the canonical OpenSSH names users type into the URL
/// (`ed25519`, `rsa`, `ecdsa`, `ecdsa-sk`, `ed25519-sk`).
public enum SSHKeyType: String, Sendable, CaseIterable, Codable {
    case ed25519
    case rsa
    case ecdsa
    case ecdsaSK = "ecdsa-sk"
    case ed25519SK = "ed25519-sk"

    public var displayName: String {
        switch self {
        case .ed25519: return "ED25519"
        case .rsa: return "RSA"
        case .ecdsa: return "ECDSA"
        case .ecdsaSK: return "ECDSA-SK"
        case .ed25519SK: return "ED25519-SK"
        }
    }

    static func from(prefix: String) -> SSHKeyType? {
        switch prefix {
        case "ssh-ed25519": return .ed25519
        case "ssh-rsa": return .rsa
        default:
            if prefix.hasPrefix("ecdsa-sha2-") { return .ecdsa }
            if prefix.hasPrefix("sk-ecdsa-sha2-") { return .ecdsaSK }
            if prefix.hasPrefix("sk-ssh-ed25519") { return .ed25519SK }
            return nil
        }
    }
}

/// Where a key was originally loaded from.
///
/// Source priority during deduplication is `manual` > `github` > `gitlab`:
/// when two sources contribute the same fingerprint, the higher-priority
/// entry wins and its comment is preserved.
public enum KeySource: String, Sendable, Codable {
    case github
    case gitlab
    case manual
}

/// A normalized representation of one OpenSSH public key, ready to render
/// or to write into `~/.ssh/authorized_keys`.
///
/// `publicKey` is always the trimmed `<type> <base64-blob> [<comment>]`
/// line. `fingerprint` is the SHA-256 of the decoded blob, encoded as
/// `SHA256:<base64-no-padding>` — identical to `ssh-keygen -lf`.
public struct SSHKey: Sendable, Hashable, Codable {
    /// Detected key family.
    public let type: SSHKeyType
    /// Original key line, trimmed.
    public let publicKey: String
    /// Comment field after the blob, if any.
    public let comment: String?
    /// Where this key was loaded from.
    public let source: KeySource
    /// SHA-256 fingerprint, format `SHA256:<base64>`.
    public let fingerprint: String

    public init(type: SSHKeyType, publicKey: String, comment: String?, source: KeySource, fingerprint: String) {
        self.type = type
        self.publicKey = publicKey
        self.comment = comment
        self.source = source
        self.fingerprint = fingerprint
    }

    public enum ParseError: Error, Equatable {
        case empty
        case unknownType(String)
        case missingBlob
    }

    public static func parse(_ line: String, source: KeySource) throws -> SSHKey {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ParseError.empty }
        let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard parts.count >= 2 else { throw ParseError.missingBlob }
        let prefix = String(parts[0])
        let blob = String(parts[1])
        guard let type = SSHKeyType.from(prefix: prefix) else {
            throw ParseError.unknownType(prefix)
        }
        let comment: String? = parts.count == 3 ? String(parts[2]) : nil
        let fp = Self.fingerprint(of: blob)
        return SSHKey(type: type, publicKey: trimmed, comment: comment, source: source, fingerprint: fp)
    }

    static func fingerprint(of base64Blob: String) -> String {
        if let data = Data(base64Encoded: base64Blob) {
            let digest = SHA256.hash(data: data)
            return "SHA256:" + Data(digest).base64EncodedString().trimmingCharacters(in: CharacterSet(charactersIn: "="))
        }
        let digest = SHA256.hash(data: Data(base64Blob.utf8))
        return "SHA256:" + Data(digest).base64EncodedString().trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }
}
