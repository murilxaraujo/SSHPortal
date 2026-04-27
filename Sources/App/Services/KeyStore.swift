import Foundation

public actor KeyStore {
    private var keys: [SSHKey]
    public private(set) var lastRefresh: Date?

    public init(initialKeys: [SSHKey] = []) {
        self.keys = initialKeys
        self.lastRefresh = initialKeys.isEmpty ? nil : Date()
    }

    public static func empty() -> KeyStore { KeyStore() }

    public func all() -> [SSHKey] { keys }
    public func filtered(by type: SSHKeyType) -> [SSHKey] { keys.filter { $0.type == type } }
    public func count() -> Int { keys.count }
}
