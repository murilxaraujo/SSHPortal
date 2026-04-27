import Foundation

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
}

public enum KeySource: String, Sendable, Codable {
    case github
    case gitlab
    case manual
}

public struct SSHKey: Sendable, Hashable, Codable {
    public let type: SSHKeyType
    public let publicKey: String
    public let comment: String?
    public let source: KeySource
    public let fingerprint: String

    public init(type: SSHKeyType, publicKey: String, comment: String?, source: KeySource, fingerprint: String) {
        self.type = type
        self.publicKey = publicKey
        self.comment = comment
        self.source = source
        self.fingerprint = fingerprint
    }
}
