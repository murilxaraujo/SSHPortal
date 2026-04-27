import Foundation

/// In-memory cache of currently-served keys.
///
/// `KeyStore` is the only mutable state in the process. ``RefreshService``
/// is the sole writer (via ``replaceAll(_:)``); HTTP handlers read with
/// ``all()``, ``filtered(by:)``, and ``count()``. Deduplication and
/// source-priority ordering happen inside ``replaceAll(_:)``.
public actor KeyStore {
    private var keys: [SSHKey]
    public private(set) var lastRefresh: Date?

    public init(initialKeys: [SSHKey] = []) {
        self.keys = Self.merge(initialKeys)
        self.lastRefresh = initialKeys.isEmpty ? nil : Date()
    }

    public static func empty() -> KeyStore { KeyStore() }

    public func all() -> [SSHKey] { keys }
    public func filtered(by type: SSHKeyType) -> [SSHKey] { keys.filter { $0.type == type } }
    public func count() -> Int { keys.count }

    public func replaceAll(_ newKeys: [SSHKey]) {
        keys = Self.merge(newKeys)
        lastRefresh = Date()
    }

    public func refreshOnce(using loader: KeyLoader) async {
        do {
            let loaded = try await loader.loadAll()
            replaceAll(loaded)
        } catch {
            // loader.loadAll currently doesn't throw, but defensive.
        }
    }

    static func merge(_ input: [SSHKey]) -> [SSHKey] {
        let sourcePriority: (KeySource) -> Int = {
            switch $0 {
            case .manual: return 0
            case .github: return 1
            case .gitlab: return 2
            }
        }
        let typePriority: (SSHKeyType) -> Int = {
            switch $0 {
            case .ed25519: return 0
            case .ed25519SK: return 1
            case .ecdsaSK: return 2
            case .ecdsa: return 3
            case .rsa: return 4
            }
        }
        let sorted = input.sorted { lhs, rhs in
            let lp = sourcePriority(lhs.source)
            let rp = sourcePriority(rhs.source)
            if lp != rp { return lp < rp }
            let lt = typePriority(lhs.type)
            let rt = typePriority(rhs.type)
            if lt != rt { return lt < rt }
            return lhs.fingerprint < rhs.fingerprint
        }
        var seen = Set<String>()
        var output: [SSHKey] = []
        for k in sorted where !seen.contains(k.fingerprint) {
            seen.insert(k.fingerprint)
            output.append(k)
        }
        return output
    }
}
